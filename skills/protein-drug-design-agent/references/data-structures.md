# Data Structures Reference

Patterns for explicit, typed data structures in protein design pipelines.

## Table of Contents

1. [Core Data Classes](#core-data-classes)
2. [Configuration Schemas](#configuration-schemas)
3. [Input Validation](#input-validation)
4. [Constraint Specification](#constraint-specification)
5. [Reproducibility Metadata](#reproducibility-metadata)

---

## Core Data Classes

Use typed dataclasses instead of ambiguous dictionaries.

```python
from dataclasses import dataclass, field, asdict
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum
from pathlib import Path

class BinderType(Enum):
    ANTIBODY = "antibody"
    NANOBODY = "nanobody"
    PEPTIDE = "peptide"
    SMALL_MOLECULE = "small_molecule"


@dataclass
class DesignSpec:
    """Specification for a protein design task."""
    target_pdb: str
    binder_type: BinderType
    epitope_residues: List[int]
    length_range: tuple = (100, 150)
    constraints: Dict[str, Any] = field(default_factory=dict)
    
    def validate(self) -> bool:
        """Validate design specification."""
        if not Path(self.target_pdb).exists():
            raise FileNotFoundError(f"Target PDB not found: {self.target_pdb}")
        if not self.epitope_residues:
            raise ValueError("At least one epitope residue required")
        if self.length_range[0] > self.length_range[1]:
            raise ValueError("Invalid length range")
        return True


@dataclass
class EpitopeResult:
    """Result of epitope prediction."""
    sequence: str
    start: int
    end: int
    core: str
    ic50: Optional[float] = None
    rank: Optional[float] = None
    allele: Optional[str] = None
    binding_class: Optional[str] = None  # "strong", "weak", None


@dataclass
class SequenceResult:
    """Result of sequence design."""
    sequence: str
    parent_id: str
    temperature: float
    score: Optional[float] = None
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class StructureResult:
    """Result of structure prediction."""
    pdb_path: str
    sequence: str
    plddt: float
    ptm: Optional[float] = None
    rmsd: Optional[float] = None
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class InterfaceAnalysisResult:
    """Result of interface analysis."""
    dg: float              # Binding free energy
    dsasa: float           # Buried surface area
    packstat: float        # Packing statistics
    buns: int              # Buried unsatisfied H-bonds
    shape_complementarity: Optional[float] = None
    hbonds: Optional[int] = None
    
    def passes_threshold(
        self,
        dg_max: float = 0.0,
        packstat_min: float = 0.6,
        buns_max: int = 5
    ) -> bool:
        """Check if interface passes quality thresholds."""
        return (
            self.dg <= dg_max and
            self.packstat >= packstat_min and
            self.buns <= buns_max
        )


@dataclass
class MHCBindingResult:
    """Result of MHC binding evaluation."""
    sequence_id: str
    allele_scores: Dict[str, float]  # IC50 per allele
    overall_score: float
    epitope_count: int
    mode: str = "reduce"  # "reduce" or "enhance"
```

---

## Configuration Schemas

Structured configuration with validation.

```python
from dataclasses import dataclass
from typing import List, Optional
import yaml
import os


@dataclass
class ModelConfig:
    """Configuration for a single model."""
    type: str
    checkpoint: str
    device: str = "cuda"
    options: Dict[str, Any] = field(default_factory=dict)
    
    def __post_init__(self):
        # Expand environment variables
        self.checkpoint = os.path.expandvars(self.checkpoint)


@dataclass
class EvaluationConfig:
    """Configuration for evaluation thresholds."""
    min_plddt: float = 80.0
    min_ptm: float = 0.7
    rmsd_threshold: float = 2.0
    dg_dsasa_threshold: float = -0.5
    packstat_threshold: float = 0.6
    buns_threshold: int = 5


@dataclass
class PipelineConfig:
    """Complete pipeline configuration."""
    # Paths
    fasta_path: str
    pdb_path: str
    output_dir: str = "results"
    
    # Mode
    mode: str = "reduce"  # "reduce" or "enhance"
    
    # Epitope settings
    epitopes_path: Optional[str] = None
    epitopes_number: int = 10
    epitope_length: int = 15
    
    # Sequence generation
    samples_per_temp: int = 20
    temperatures: List[float] = field(default_factory=lambda: [0.1, 0.3, 0.5])
    
    # Structure prediction
    max_candidates: int = 10
    
    # Evaluation
    evaluation: EvaluationConfig = field(default_factory=EvaluationConfig)
    
    # Models
    models: Dict[str, ModelConfig] = field(default_factory=dict)
    
    # Logging
    log_level: str = "INFO"
    
    # Reproducibility
    random_seed: int = 42
    
    @classmethod
    def from_yaml(cls, path: str) -> "PipelineConfig":
        """Load configuration from YAML file."""
        with open(path, 'r') as f:
            data = yaml.safe_load(f)
        
        # Expand environment variables
        data = cls._expand_env_vars(data)
        
        # Handle nested configs
        if 'evaluation' in data and isinstance(data['evaluation'], dict):
            data['evaluation'] = EvaluationConfig(**data['evaluation'])
        
        if 'models' in data:
            data['models'] = {
                k: ModelConfig(**v) for k, v in data['models'].items()
            }
        
        return cls(**data)
    
    @staticmethod
    def _expand_env_vars(data: dict) -> dict:
        """Recursively expand environment variables."""
        if isinstance(data, dict):
            return {k: PipelineConfig._expand_env_vars(v) for k, v in data.items()}
        elif isinstance(data, list):
            return [PipelineConfig._expand_env_vars(v) for v in data]
        elif isinstance(data, str):
            return os.path.expandvars(data)
        return data
    
    def validate(self) -> tuple:
        """Validate configuration. Returns (is_valid, errors)."""
        errors = []
        
        # Check required paths
        if not Path(self.fasta_path).exists():
            errors.append(f"FASTA file not found: {self.fasta_path}")
        if not Path(self.pdb_path).exists():
            errors.append(f"PDB file not found: {self.pdb_path}")
        
        # Check mode
        if self.mode not in ("reduce", "enhance"):
            errors.append(f"Invalid mode: {self.mode}. Must be 'reduce' or 'enhance'")
        
        # Check numeric ranges
        if not 0 < self.epitopes_number <= 50:
            errors.append(f"epitopes_number must be 1-50, got {self.epitopes_number}")
        if not 9 <= self.epitope_length <= 25:
            errors.append(f"epitope_length must be 9-25, got {self.epitope_length}")
        
        # Check model checkpoints
        for name, model in self.models.items():
            if not Path(model.checkpoint).exists():
                errors.append(f"Model checkpoint not found: {model.checkpoint}")
        
        return len(errors) == 0, errors
    
    def to_dict(self) -> dict:
        """Convert to dictionary for serialization."""
        return asdict(self)
    
    def save(self, path: str):
        """Save configuration to YAML."""
        with open(path, 'w') as f:
            yaml.dump(self.to_dict(), f, default_flow_style=False)
```

---

## Input Validation

Validate data at pipeline boundaries.

```python
from typing import Protocol, TypeVar, Generic
from pydantic import BaseModel, validator, root_validator
from pathlib import Path

# Using Pydantic for validation
class StageInput(BaseModel):
    """Validated input for pipeline stages."""
    stage: str
    timestamp: str
    fasta_path: str
    pdb_path: str
    output_dir: str
    
    @validator('fasta_path', 'pdb_path')
    def path_must_exist(cls, v):
        if not Path(v).exists():
            raise ValueError(f"File not found: {v}")
        return v
    
    @validator('output_dir')
    def create_output_dir(cls, v):
        Path(v).mkdir(parents=True, exist_ok=True)
        return v
    
    class Config:
        extra = 'allow'  # Allow additional fields


class EpitopeStageInput(StageInput):
    """Input for epitope prediction stage."""
    epitopes_path: Optional[str] = None
    epitopes_number: int = 10
    epitope_length: int = 15
    
    @validator('epitopes_path')
    def validate_epitopes_file(cls, v):
        if v and not Path(v).exists():
            raise ValueError(f"Epitopes file not found: {v}")
        return v
    
    @validator('epitope_length')
    def validate_length(cls, v):
        if not 9 <= v <= 25:
            raise ValueError(f"epitope_length must be 9-25, got {v}")
        return v


class SequenceStageInput(StageInput):
    """Input for sequence generation stage."""
    epitope_df: List[dict]  # List of EpitopeResult dicts
    
    @validator('epitope_df')
    def validate_epitopes(cls, v):
        if not v:
            raise ValueError("No epitopes provided")
        required = {'sequence', 'start', 'end'}
        for ep in v:
            missing = required - set(ep.keys())
            if missing:
                raise ValueError(f"Epitope missing fields: {missing}")
        return v


# Usage in stage
class EpitopePredictionStage(PipelineStage):
    def process(self, input_data: PipelineData) -> PipelineData:
        # Validate input using Pydantic
        validated = EpitopeStageInput(
            stage=input_data.stage,
            timestamp=input_data.timestamp,
            **input_data.metadata
        )
        
        # Now use validated.fasta_path, etc.
        ...
```

---

## Constraint Specification

Rich constraint system for design tasks.

```python
@dataclass
class ResidueRange:
    """Range of residues."""
    start: int
    end: int
    chain: str = "A"
    
    def __contains__(self, residue: int) -> bool:
        return self.start <= residue <= self.end


@dataclass
class BindingSite:
    """Binding site specification."""
    residues: List[int]
    chain: str = "A"
    distance_threshold: float = 5.0  # Angstroms
    required_contacts: int = 3


@dataclass
class StructuralMotif:
    """Structural motif constraint."""
    type: str  # "helix", "sheet", "loop"
    residue_range: ResidueRange
    reference_pdb: Optional[str] = None


@dataclass
class CovalentBond:
    """Covalent bond constraint."""
    residue1: int
    residue2: int
    chain1: str = "A"
    chain2: str = "B"
    bond_type: str = "disulfide"


@dataclass
class SymmetryGroup:
    """Symmetry constraint."""
    type: str  # "C2", "C3", "D2", etc.
    chains: List[str]


@dataclass
class ConstraintSpec:
    """
    Complete constraint specification for protein design.
    Inspired by BoltzGen's constraint system.
    """
    binding_sites: Optional[List[BindingSite]] = None
    fixed_regions: Optional[List[ResidueRange]] = None
    designable_regions: Optional[List[ResidueRange]] = None
    structural_motifs: Optional[List[StructuralMotif]] = None
    covalent_bonds: Optional[List[CovalentBond]] = None
    symmetry: Optional[SymmetryGroup] = None
    
    # Sequence constraints
    forbidden_residues: Dict[int, List[str]] = field(default_factory=dict)
    required_residues: Dict[int, str] = field(default_factory=dict)
    
    def to_proteinmpnn_format(self) -> dict:
        """Convert to ProteinMPNN input format."""
        # Model-specific conversion
        ...
    
    def to_rfdiffusion_format(self) -> dict:
        """Convert to RFdiffusion input format."""
        # Model-specific conversion
        ...
    
    def validate(self) -> bool:
        """Validate constraint consistency."""
        # Check for conflicts
        if self.fixed_regions and self.designable_regions:
            for fixed in self.fixed_regions:
                for design in self.designable_regions:
                    if self._ranges_overlap(fixed, design):
                        raise ValueError("Fixed and designable regions overlap")
        return True
    
    @staticmethod
    def _ranges_overlap(r1: ResidueRange, r2: ResidueRange) -> bool:
        return r1.chain == r2.chain and not (r1.end < r2.start or r2.end < r1.start)
```

---

## Reproducibility Metadata

Track everything needed to reproduce results.

```python
import subprocess
import platform
import sys
from datetime import datetime
import hashlib
import json

@dataclass
class RunMetadata:
    """Comprehensive metadata for reproducibility."""
    # Identification
    run_id: str
    timestamp: str
    
    # Configuration
    config_path: str
    config_hash: str
    
    # Version control
    git_commit: Optional[str]
    git_branch: Optional[str]
    git_dirty: bool  # Uncommitted changes?
    
    # Environment
    python_version: str
    package_versions: Dict[str, str]
    
    # System
    platform: str
    cpu_count: int
    gpu_info: Optional[str]
    
    # Reproducibility
    random_seed: int
    
    # Results
    execution_time: float = 0.0
    status: str = "running"  # "running", "completed", "failed"
    
    @classmethod
    def create(cls, config_path: str, random_seed: int = 42) -> "RunMetadata":
        """Create metadata for a new run."""
        return cls(
            run_id=cls._generate_run_id(),
            timestamp=datetime.now().isoformat(),
            config_path=config_path,
            config_hash=cls._hash_file(config_path),
            git_commit=cls._get_git_commit(),
            git_branch=cls._get_git_branch(),
            git_dirty=cls._is_git_dirty(),
            python_version=sys.version,
            package_versions=cls._get_package_versions(),
            platform=platform.platform(),
            cpu_count=os.cpu_count(),
            gpu_info=cls._get_gpu_info(),
            random_seed=random_seed
        )
    
    @staticmethod
    def _generate_run_id() -> str:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        import random
        suffix = ''.join(random.choices('abcdefghijklmnopqrstuvwxyz', k=4))
        return f"run_{timestamp}_{suffix}"
    
    @staticmethod
    def _hash_file(path: str) -> str:
        with open(path, 'rb') as f:
            return hashlib.md5(f.read()).hexdigest()
    
    @staticmethod
    def _get_git_commit() -> Optional[str]:
        try:
            return subprocess.check_output(
                ['git', 'rev-parse', 'HEAD'],
                stderr=subprocess.DEVNULL
            ).decode().strip()
        except:
            return None
    
    @staticmethod
    def _get_git_branch() -> Optional[str]:
        try:
            return subprocess.check_output(
                ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                stderr=subprocess.DEVNULL
            ).decode().strip()
        except:
            return None
    
    @staticmethod
    def _is_git_dirty() -> bool:
        try:
            result = subprocess.run(
                ['git', 'diff', '--quiet'],
                capture_output=True
            )
            return result.returncode != 0
        except:
            return False
    
    @staticmethod
    def _get_package_versions() -> Dict[str, str]:
        """Get versions of key packages."""
        packages = ['torch', 'numpy', 'pandas', 'biopython', 'scipy']
        versions = {}
        for pkg in packages:
            try:
                import importlib
                mod = importlib.import_module(pkg)
                versions[pkg] = getattr(mod, '__version__', 'unknown')
            except ImportError:
                pass
        return versions
    
    @staticmethod
    def _get_gpu_info() -> Optional[str]:
        try:
            import torch
            if torch.cuda.is_available():
                return torch.cuda.get_device_name(0)
        except:
            pass
        return None
    
    def save(self, path: str):
        """Save metadata to JSON."""
        with open(path, 'w') as f:
            json.dump(asdict(self), f, indent=2)
    
    @classmethod
    def load(cls, path: str) -> "RunMetadata":
        """Load metadata from JSON."""
        with open(path, 'r') as f:
            return cls(**json.load(f))
```

---

## Best Practices Summary

| Aspect | Recommendation |
|--------|----------------|
| Typing | Use `@dataclass` with type hints |
| Validation | Validate at boundaries (Pydantic) |
| Serialization | Implement `to_dict()` and `from_dict()` |
| Immutability | Prefer frozen dataclasses for results |
| Defaults | Provide sensible defaults |
| Documentation | Docstrings on all fields |
| Conversion | Implement model-specific format converters |
