# Model Integration Reference

Patterns for integrating external models (AlphaFold3, ProteinMPNN, Rosetta, etc.) into protein design pipelines.

## Table of Contents

1. [Model Wrapper Abstraction](#model-wrapper-abstraction)
2. [Model Factory Pattern](#model-factory-pattern)
3. [Resource Management](#resource-management)
4. [External Tool Wrappers](#external-tool-wrappers)
5. [Configuration-Driven Model Selection](#configuration-driven-model-selection)
6. [Error Handling & Fallbacks](#error-handling--fallbacks)

---

## Model Wrapper Abstraction

Define abstract interfaces so models can be swapped without changing pipeline code.

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List, Optional
import logging

logger = logging.getLogger(__name__)

@dataclass
class StructureResult:
    """Standard output for structure prediction."""
    pdb_path: str
    sequence: str
    confidence: float  # pLDDT or similar
    metadata: dict


class StructurePredictor(ABC):
    """Abstract interface for structure prediction models."""
    
    @abstractmethod
    def predict(self, sequence: str, output_dir: str) -> StructureResult:
        """Predict structure from sequence."""
        pass
    
    @abstractmethod
    def predict_batch(self, sequences: List[str], output_dir: str) -> List[StructureResult]:
        """Batch prediction."""
        pass
    
    @abstractmethod
    def get_requirements(self) -> dict:
        """Return model requirements (GPU, memory, etc.)"""
        pass


class AlphaFold3Predictor(StructurePredictor):
    """AlphaFold3 implementation."""
    
    def __init__(self, checkpoint_path: str, device: str = "cuda"):
        self.checkpoint_path = checkpoint_path
        self.device = device
        self._model = None  # Lazy loading
    
    def predict(self, sequence: str, output_dir: str) -> StructureResult:
        self._ensure_loaded()
        # ... AlphaFold3 specific logic
        return StructureResult(
            pdb_path=f"{output_dir}/prediction.pdb",
            sequence=sequence,
            confidence=0.92,
            metadata={"model": "alphafold3"}
        )
    
    def predict_batch(self, sequences: List[str], output_dir: str) -> List[StructureResult]:
        return [self.predict(seq, f"{output_dir}/{i}") for i, seq in enumerate(sequences)]
    
    def get_requirements(self) -> dict:
        return {"gpu": True, "min_memory_gb": 16, "cuda_version": "11.8+"}
    
    def _ensure_loaded(self):
        if self._model is None:
            logger.info("Loading AlphaFold3 model...")
            # self._model = load_alphafold3(self.checkpoint_path)


class ColabFoldPredictor(StructurePredictor):
    """ColabFold implementation (alternative backend)."""
    
    def predict(self, sequence: str, output_dir: str) -> StructureResult:
        # ColabFold specific logic
        ...
    
    def predict_batch(self, sequences: List[str], output_dir: str) -> List[StructureResult]:
        ...
    
    def get_requirements(self) -> dict:
        return {"gpu": True, "min_memory_gb": 8}
```

---

## Model Factory Pattern

Centralized model creation with lazy loading and caching.

```python
import threading
from typing import Dict, Type

class ModelFactory:
    """
    Factory for creating and caching model instances.
    
    Benefits:
    - Lazy loading (load on first use)
    - Singleton pattern (one instance per config)
    - Thread-safe initialization
    - Memory management
    """
    
    _instances: Dict[str, object] = {}
    _lock = threading.Lock()
    _registry: Dict[str, Type] = {}
    
    @classmethod
    def register(cls, name: str, model_class: Type):
        """Register a model class."""
        cls._registry[name] = model_class
    
    @classmethod
    def get_model(cls, model_type: str, checkpoint: str, device: str = "cuda"):
        """Get or create model instance."""
        key = f"{model_type}:{checkpoint}:{device}"
        
        if key not in cls._instances:
            with cls._lock:
                # Double-check after acquiring lock
                if key not in cls._instances:
                    cls._instances[key] = cls._create(model_type, checkpoint, device)
        
        return cls._instances[key]
    
    @classmethod
    def _create(cls, model_type: str, checkpoint: str, device: str):
        """Create new model instance."""
        if model_type not in cls._registry:
            raise ValueError(f"Unknown model: {model_type}. Available: {list(cls._registry.keys())}")
        
        logger.info(f"Creating {model_type} model from {checkpoint}")
        model_class = cls._registry[model_type]
        return model_class(checkpoint, device)
    
    @classmethod
    def clear_cache(cls):
        """Clear all cached models to free memory."""
        with cls._lock:
            import torch
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            cls._instances.clear()
            logger.info("Model cache cleared")
    
    @classmethod
    def get_loaded_models(cls) -> List[str]:
        """List currently loaded models."""
        return list(cls._instances.keys())


# Register models
ModelFactory.register("alphafold3", AlphaFold3Predictor)
ModelFactory.register("colabfold", ColabFoldPredictor)
ModelFactory.register("rfdiffusion", RFdiffusionPredictor)

# Usage
model = ModelFactory.get_model("alphafold3", "/path/to/weights", "cuda:0")
result = model.predict(sequence, output_dir)
```

---

## Resource Management

Handle GPU memory, model loading, and cleanup.

```python
import torch
from contextlib import contextmanager

class ResourceManager:
    """Manage computational resources across pipeline."""
    
    def __init__(self, device: str = "cuda"):
        self.device = device
        self._active_models = []
    
    @contextmanager
    def model_context(self, model_name: str):
        """Context manager for model usage with cleanup."""
        try:
            yield
        finally:
            self._cleanup_after_inference()
    
    def _cleanup_after_inference(self):
        """Clear GPU cache after inference."""
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
    
    def check_requirements(self, model_type: str) -> bool:
        """Check if system meets model requirements."""
        requirements = {
            "alphafold3": {"gpu_memory_gb": 16},
            "rfdiffusion": {"gpu_memory_gb": 12},
            "proteinmpnn": {"gpu_memory_gb": 4}
        }
        
        if model_type not in requirements:
            return True
        
        req = requirements[model_type]
        if "gpu_memory_gb" in req and torch.cuda.is_available():
            available = torch.cuda.get_device_properties(0).total_memory / 1e9
            if available < req["gpu_memory_gb"]:
                logger.warning(
                    f"{model_type} requires {req['gpu_memory_gb']}GB GPU memory, "
                    f"but only {available:.1f}GB available"
                )
                return False
        return True
    
    def get_optimal_batch_size(self, model_type: str, sequence_length: int) -> int:
        """Estimate optimal batch size based on available memory."""
        if not torch.cuda.is_available():
            return 1
        
        available_gb = torch.cuda.get_device_properties(0).total_memory / 1e9
        
        # Rough estimates (adjust based on actual model behavior)
        memory_per_sample = {
            "alphafold3": 0.5 * sequence_length / 100,  # ~0.5GB per 100 residues
            "proteinmpnn": 0.1 * sequence_length / 100,
            "esm": 0.2 * sequence_length / 100
        }
        
        per_sample = memory_per_sample.get(model_type, 0.5)
        max_batch = int(available_gb * 0.8 / per_sample)  # Use 80% of memory
        return max(1, min(max_batch, 32))


# Usage in pipeline stage
class StructurePredictionStage(PipelineStage):
    def __init__(self, config: dict):
        super().__init__("structure_prediction", config)
        self.resource_manager = ResourceManager()
    
    def process(self, input_data: PipelineData) -> PipelineData:
        model_type = self.config.get('model', 'alphafold3')
        
        if not self.resource_manager.check_requirements(model_type):
            logger.warning(f"System may not meet {model_type} requirements")
        
        with self.resource_manager.model_context(model_type):
            model = ModelFactory.get_model(model_type, self.config['checkpoint'])
            results = model.predict_batch(
                input_data.metadata['sequences'],
                input_data.metadata['output_dir']
            )
        
        return PipelineData(
            stage=self.name,
            metadata={**input_data.metadata, 'structure_results': results}
        )
```

---

## External Tool Wrappers

Wrap command-line tools with Python interfaces.

```python
import subprocess
import tempfile
import os
from pathlib import Path

class ExternalToolWrapper(ABC):
    """Base class for wrapping external command-line tools."""
    
    def __init__(self, tool_path: str):
        self.tool_path = Path(tool_path)
        self._validate_installation()
    
    def _validate_installation(self):
        """Check tool is installed and accessible."""
        if not self.tool_path.exists():
            raise FileNotFoundError(f"Tool not found: {self.tool_path}")
    
    def _run_command(self, cmd: List[str], timeout: int = 3600) -> str:
        """Run command with error handling."""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
                check=True
            )
            return result.stdout
        except subprocess.TimeoutExpired:
            raise TimeoutError(f"Command timed out after {timeout}s")
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Command failed: {e.stderr}")


class NetMHCIIpanWrapper(ExternalToolWrapper):
    """Wrapper for NetMHCIIpan MHC-II binding prediction."""
    
    def __init__(self, tool_path: str = None):
        tool_path = tool_path or os.environ.get("NETMHCIIPAN_PATH")
        if not tool_path:
            raise ValueError("NetMHCIIpan path not configured")
        super().__init__(tool_path)
    
    def predict(
        self, 
        fasta_path: str, 
        alleles: List[str],
        output_dir: str
    ) -> pd.DataFrame:
        """Run NetMHCIIpan prediction."""
        output_file = Path(output_dir) / "netmhcii_output.txt"
        
        cmd = [
            str(self.tool_path / "netMHCIIpan"),
            "-f", fasta_path,
            "-a", ",".join(alleles),
            "-xls", "-xlsfile", str(output_file)
        ]
        
        self._run_command(cmd)
        return self._parse_output(output_file)
    
    def _parse_output(self, output_file: Path) -> pd.DataFrame:
        """Parse NetMHCIIpan output to DataFrame."""
        # ... parsing logic
        pass


class RosettaWrapper(ExternalToolWrapper):
    """Wrapper for Rosetta interface analysis."""
    
    def calculate_interface_metrics(
        self, 
        pdb_path: str, 
        output_dir: str
    ) -> dict:
        """Calculate interface metrics using Rosetta InterfaceAnalyzer."""
        cmd = [
            str(self.tool_path / "InterfaceAnalyzer.default.linuxgccrelease"),
            "-s", pdb_path,
            "-out:path:all", output_dir,
            "-pack_separated",
            "-compute_packstat"
        ]
        
        self._run_command(cmd)
        return self._parse_metrics(Path(output_dir))
    
    def _parse_metrics(self, output_dir: Path) -> dict:
        """Parse Rosetta output for metrics."""
        # Parse dG, dSASA, packstat, BUNS, etc.
        return {
            "dg": -5.2,
            "dsasa": 1200.0,
            "packstat": 0.72,
            "buns": 3
        }
```

---

## Configuration-Driven Model Selection

Select models via configuration, not hard-coded logic.

```yaml
# config.yaml
models:
  structure_predictor:
    type: "alphafold3"
    checkpoint: "${ALPHAFOLD3_CHECKPOINT}"
    device: "cuda:0"
    options:
      num_recycles: 3
      max_msa_clusters: 128
  
  sequence_designer:
    type: "proteinmpnn"
    checkpoint: "${PROTEINMPNN_CHECKPOINT}"
    options:
      temperature: 0.1
      samples_per_position: 10
  
  fallback:
    structure_predictor: "colabfold"  # Use if primary fails
```

```python
def get_model_from_config(config: dict, model_key: str):
    """Get model based on config."""
    model_config = config['models'].get(model_key)
    if not model_config:
        raise ValueError(f"Model config not found: {model_key}")
    
    model_type = model_config['type']
    checkpoint = os.path.expandvars(model_config['checkpoint'])
    device = model_config.get('device', 'cuda')
    
    return ModelFactory.get_model(model_type, checkpoint, device)
```

---

## Error Handling & Fallbacks

Handle model failures gracefully with fallback options.

```python
class RobustPredictor:
    """Predictor with automatic fallback."""
    
    def __init__(self, primary: str, fallback: str, config: dict):
        self.primary_type = primary
        self.fallback_type = fallback
        self.config = config
    
    def predict(self, sequence: str, output_dir: str) -> StructureResult:
        """Predict with fallback on failure."""
        try:
            model = ModelFactory.get_model(
                self.primary_type,
                self.config[self.primary_type]['checkpoint']
            )
            return model.predict(sequence, output_dir)
        
        except Exception as e:
            logger.warning(f"{self.primary_type} failed: {e}. Trying {self.fallback_type}")
            
            try:
                fallback = ModelFactory.get_model(
                    self.fallback_type,
                    self.config[self.fallback_type]['checkpoint']
                )
                result = fallback.predict(sequence, output_dir)
                result.metadata['fallback_used'] = True
                return result
            
            except Exception as e2:
                logger.error(f"Both predictors failed: {e2}")
                raise RuntimeError(f"Structure prediction failed with all backends")


# Retry with exponential backoff
import time
from functools import wraps

def retry_with_backoff(max_retries: int = 3, base_delay: float = 1.0):
    """Decorator for retry with exponential backoff."""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == max_retries - 1:
                        raise
                    delay = base_delay * (2 ** attempt)
                    logger.warning(f"Attempt {attempt + 1} failed: {e}. Retrying in {delay}s")
                    time.sleep(delay)
        return wrapper
    return decorator


@retry_with_backoff(max_retries=3)
def predict_structure_with_retry(model, sequence, output_dir):
    return model.predict(sequence, output_dir)
```

---

## Best Practices Summary

| Aspect | Recommendation |
|--------|----------------|
| Abstraction | Use abstract base classes for all model types |
| Initialization | Lazy load models on first use |
| Caching | Cache model instances (singleton per config) |
| Memory | Clear GPU cache between stages |
| Fallbacks | Configure backup models for critical steps |
| Config | Use env vars for paths, YAML for parameters |
| Validation | Check requirements before model loading |
