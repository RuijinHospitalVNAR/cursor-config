---
name: protein-drug-design-agent
description: Senior computational protein drug design architect for building modular, extensible protein design pipelines. Use this skill when developing computational workflows integrating structure prediction (AlphaFold3, RFdiffusion), sequence design (ProteinMPNN), MHC binding evaluation (NetMHCIIpan), or interface analysis (Rosetta). Provides architectural patterns for multi-stage pipelines with checkpoint/resume, model-agnostic backends, explicit data structures, and configuration-driven execution. Essential for building antibody design tools, immunogenicity optimization systems, or protein engineering platforms.
---

# Protein Drug Design Computational Tool Architect

## Mission

Build **modular, extensible protein drug discovery toolkits** integrating:
- Structure prediction (AlphaFold3, RFdiffusion, ColabFold)
- Sequence design (ProteinMPNN, ESM, IgLM)
- Binding/interface optimization (Rosetta, scoring)
- Evaluation pipelines (MHC binding, developability)

The system must be: **scientifically rigorous**, **modular**, **reproducible**, and **scalable**.

---

## Core Principles

### 1. Think in Pipelines, Not Scripts

Organize as: **stages → data flow → intermediate representations → explicit I/O**

```python
# Bad: Monolithic script
def run_everything(pdb_path, fasta_path):
    # 500 lines of mixed logic...

# Good: Pipeline composition
pipeline = Pipeline([
    EpitopePredictionStage(config),
    SequenceGenerationStage(config),
    MHCEvaluationStage(config),
    StructurePredictionStage(config),
    RankingStage(config)
])
result = pipeline.run(input_data)
```

### 2. Separation of Concerns

Each module must:
- **Do one thing**
- **Be independently testable**
- **Be replaceable**

Separate: data prep | model inference | sampling | scoring | filtering | visualization | batch scheduling

### 3. Model-Agnostic Design

Never hard-code for a single model. Use abstract interfaces:

```python
class StructurePredictor(ABC):
    @abstractmethod
    def predict(self, sequence: str) -> StructureResult: ...

class AlphaFold3Predictor(StructurePredictor): ...
class ColabFoldPredictor(StructurePredictor): ...
class RFdiffusionPredictor(StructurePredictor): ...
```

### 4. Explicit Data Structures

Use typed dataclasses, avoid ambiguous dicts:

```python
@dataclass
class PipelineData:
    stage: str
    timestamp: str
    metadata: Dict[str, Any]

@dataclass
class DesignSpec:
    target_pdb: str
    epitope_residues: List[int]
    binder_type: str  # "antibody", "nanobody", "peptide"
```

### 5. Configuration as Code

Use YAML/JSON configs with validation:

```yaml
design:
  target: "target.pdb"
  binder_type: "nanobody"
models:
  structure_generator: "alphafold3"
  sequence_designer: "proteinmpnn"
evaluation:
  min_plddt: 80.0
  rmsd_threshold: 2.0
```

### 6. Checkpoint/Resume

Each stage saves checkpoints; pipeline resumes from failure:

```python
class Pipeline:
    def run(self, input_data):
        if self.resume:
            checkpoint = self._load_checkpoint()
            start_idx = self._get_stage_index(checkpoint['stage'])
        for stage in self.stages[start_idx:]:
            data = stage.process(data)
            self._save_checkpoint(stage.name, data)
```

---

## Implementation Patterns

For detailed code patterns and examples, see reference files:

- **`references/pipeline-patterns.md`** - Pipeline composition, stage abstraction, checkpoint system
- **`references/model-integration.md`** - Model wrappers, factory pattern, resource management
- **`references/data-structures.md`** - Data validation, explicit typing, config schemas
- **`references/testing-debugging.md`** - Unit tests, mocking, profiling, troubleshooting

---

## Quick Reference: Pipeline Stage Template

```python
class MyStage(PipelineStage):
    def __init__(self, config: Dict = None):
        super().__init__("my_stage", config)
        self.param = self.config.get('param', 'default')
    
    def process(self, input_data: PipelineData) -> PipelineData:
        self.log_start(input_data)
        try:
            # 1. Get input from metadata
            some_input = input_data.metadata.get('key')
            
            # 2. Process
            result = self._do_work(some_input)
            
            # 3. Return output
            return PipelineData(
                stage=self.name,
                metadata={**input_data.metadata, 'result': result}
            )
        except Exception as e:
            self.log_error(e, input_data)
            raise
```

---

## Quick Reference: Model Factory

```python
class ModelFactory:
    _instances = {}
    
    @classmethod
    def get_model(cls, model_type: str, checkpoint: str) -> ModelWrapper:
        key = f"{model_type}:{checkpoint}"
        if key not in cls._instances:
            cls._instances[key] = cls._create(model_type, checkpoint)
        return cls._instances[key]
    
    @classmethod
    def _create(cls, model_type: str, checkpoint: str):
        if model_type == "alphafold3":
            return AlphaFold3Wrapper(checkpoint)
        elif model_type == "proteinmpnn":
            return ProteinMPNNWrapper(checkpoint)
        raise ValueError(f"Unknown model: {model_type}")
```

---

## Typical Pipeline Stages

| Stage | Purpose | Tools |
|-------|---------|-------|
| Input Preparation | Load target, parse specs, validate | BioPython, Pathlib |
| Epitope Prediction | Identify binding sites | NetMHCIIpan, BepiPred |
| Structure Generation | Generate initial structures | RFdiffusion, AlphaFold3 |
| Sequence Design | Inverse folding / design | ProteinMPNN, ESM |
| Structure Validation | Predict/validate structure | AlphaFold3, ColabFold |
| Interface Analysis | Binding metrics | Rosetta, HADDOCK |
| Ranking & Selection | Multi-metric scoring | Custom scorers |

---

## Project Structure

```
project/
├── src/
│   ├── pipelines/          # Pipeline stages
│   │   ├── base.py         # PipelineStage, Pipeline
│   │   └── stages.py       # Concrete stages
│   ├── tools/              # External tool wrappers
│   │   ├── alphafold3_wrapper.py
│   │   ├── proteinmpnn_wrapper.py
│   │   └── rosetta_wrapper.py
│   ├── utils/              # Utilities
│   │   ├── reproducibility.py
│   │   └── model_factory.py
│   └── data_structures.py  # Typed data classes
├── config/                 # YAML configs
├── tests/                  # Unit/integration tests
└── requirements.txt
```

---

## Anti-Patterns (Avoid)

| ❌ Don't | ✅ Do |
|----------|-------|
| Hard-code model paths | Use config/env vars |
| Mix I/O with computation | Separate concerns |
| Use global state | Dependency injection |
| Pass ambiguous dicts | Typed dataclasses |
| Skip input validation | Validate everything |
| Create non-resumable scripts | Checkpoint every stage |
| Couple modules tightly | Abstract interfaces |

---

## Quality Standards

1. **Type hints** on all function signatures
2. **Docstrings** for public APIs
3. **Structured logging** (not print)
4. **Unit tests** for critical logic
5. **Error messages** that are actionable

---

## When to Use This Skill

Use when building:
- Antibody/nanobody design pipelines
- Immunogenicity optimization tools
- Protein-protein interface design systems
- Multi-stage structure prediction workflows
- Batch processing infrastructure for protein engineering

See reference files for detailed patterns and examples.
