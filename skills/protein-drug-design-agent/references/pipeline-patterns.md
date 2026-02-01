# Pipeline Patterns Reference

Detailed code patterns for building modular protein design pipelines.

## Table of Contents

1. [Pipeline Composition](#pipeline-composition)
2. [Abstract Stage Interface](#abstract-stage-interface)
3. [Concrete Stage Implementation](#concrete-stage-implementation)
4. [Checkpoint System](#checkpoint-system)
5. [Flexible Execution](#flexible-execution)
6. [Factory Function](#factory-function)

---

## Pipeline Composition

The core pipeline pattern: stages execute sequentially, each transforming `PipelineData`.

```python
from typing import List, Optional
from abc import ABC, abstractmethod
from dataclasses import dataclass, field, asdict
from datetime import datetime
from pathlib import Path
import json
import logging

logger = logging.getLogger(__name__)

@dataclass
class PipelineData:
    """Standard data structure for stage I/O."""
    stage: str
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())
    metadata: dict = field(default_factory=dict)
    
    def to_dict(self) -> dict:
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: dict) -> "PipelineData":
        return cls(**data)


class Pipeline:
    """Compose and execute stages with checkpoint support."""
    
    def __init__(
        self,
        stages: List["PipelineStage"],
        checkpoint_dir: Optional[Path] = None,
        resume: bool = False
    ):
        self.stages = stages
        self.checkpoint_dir = checkpoint_dir or Path("checkpoints")
        self.checkpoint_dir.mkdir(parents=True, exist_ok=True)
        self.resume = resume
    
    def run(self, input_data: PipelineData) -> PipelineData:
        """Run all stages sequentially."""
        data = input_data
        start_idx = 0
        
        if self.resume:
            checkpoint = self._load_checkpoint()
            if checkpoint:
                data = PipelineData.from_dict(checkpoint['data'])
                start_idx = self._get_next_stage_index(checkpoint['stage'])
        
        for stage in self.stages[start_idx:]:
            data = stage.process(data)
            data.stage = stage.name
            data.timestamp = datetime.now().isoformat()
            self._save_checkpoint(stage.name, data)
        
        return data
```

---

## Abstract Stage Interface

Base class defining the contract for all pipeline stages.

```python
class PipelineStage(ABC):
    """
    Abstract base for pipeline stages.
    
    Each stage must:
    - Do one thing
    - Be independently testable
    - Be replaceable
    """
    
    def __init__(self, name: str, config: Optional[dict] = None):
        self.name = name
        self.config = config or {}
        self.logger = logging.getLogger(f"{__name__}.{name}")
    
    @abstractmethod
    def process(self, input_data: PipelineData) -> PipelineData:
        """
        Process input and return output.
        
        Args:
            input_data: Input from previous stage
            
        Returns:
            Output for next stage
        """
        pass
    
    def validate_input(self, input_data: PipelineData) -> bool:
        """Override to add input validation."""
        return isinstance(input_data, PipelineData)
    
    def log_start(self, input_data: PipelineData):
        self.logger.info(f"Starting stage: {self.name}")
    
    def log_complete(self, output_data: PipelineData):
        self.logger.info(f"Completed stage: {self.name}")
    
    def log_error(self, error: Exception, input_data: PipelineData):
        self.logger.error(f"Stage {self.name} failed: {error}", exc_info=True)
```

---

## Concrete Stage Implementation

Template for implementing specific stages.

```python
class SequenceGenerationStage(PipelineStage):
    """Generate mutant sequences using ProteinMPNN."""
    
    def __init__(self, config: Optional[dict] = None):
        super().__init__("sequence_generation", config)
        self.samples_per_temp = self.config.get('samples_per_temp', 20)
        self.temperatures = self.config.get('temperatures', [0.1, 0.3, 0.5])
    
    def process(self, input_data: PipelineData) -> PipelineData:
        self.log_start(input_data)
        
        # 1. Extract inputs
        pdb_path = input_data.metadata.get('pdb_path')
        epitopes = input_data.metadata.get('epitope_df', [])
        
        if not pdb_path:
            raise ValueError("pdb_path required in input metadata")
        
        try:
            # 2. Call external tool
            from ..tools.protein_mpnn_wrapper import generate_mutants
            mutants = generate_mutants(
                pdb_path, 
                epitopes,
                samples_per_temp=self.samples_per_temp,
                temps=self.temperatures
            )
            
            # 3. Construct output
            output_data = PipelineData(
                stage=self.name,
                metadata={
                    **input_data.metadata,
                    'mutants': mutants,
                    'mutant_count': len(mutants)
                }
            )
            
            self.log_complete(output_data)
            return output_data
            
        except Exception as e:
            self.log_error(e, input_data)
            raise
```

---

## Checkpoint System

Save and load checkpoints for resume capability.

```python
class Pipeline:
    # ... (from above)
    
    def _save_checkpoint(self, stage_name: str, data: PipelineData, error: str = None):
        """Save checkpoint after stage completion."""
        checkpoint = {
            "stage": stage_name,
            "data": data.to_dict(),
            "timestamp": datetime.now().isoformat(),
            "pipeline_version": "1.0.0",
            "error": error
        }
        
        path = self.checkpoint_dir / f"checkpoint_{stage_name}.json"
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(checkpoint, f, indent=2, ensure_ascii=False)
    
    def _load_checkpoint(self) -> Optional[dict]:
        """Load latest checkpoint."""
        files = sorted(self.checkpoint_dir.glob("checkpoint_*.json"))
        if not files:
            return None
        
        with open(files[-1], 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def _load_checkpoint_for_stage(self, stage_name: str) -> Optional[dict]:
        """Load specific stage checkpoint."""
        path = self.checkpoint_dir / f"checkpoint_{stage_name}.json"
        if not path.exists():
            return None
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def _get_next_stage_index(self, stage_name: str) -> int:
        """Get index of stage after the given one."""
        for idx, stage in enumerate(self.stages):
            if stage.name == stage_name:
                return idx + 1
        return 0
    
    def get_stage_status(self) -> dict:
        """Get completion status of each stage."""
        status = {}
        for stage in self.stages:
            checkpoint = self._load_checkpoint_for_stage(stage.name)
            if checkpoint:
                status[stage.name] = 'error' if checkpoint.get('error') else 'completed'
            else:
                status[stage.name] = 'pending'
        return status
```

---

## Flexible Execution

Run single stages, ranges, or from specific points.

```python
class Pipeline:
    # ... (from above)
    
    def run_stage(self, stage_name: str, input_data: PipelineData = None) -> PipelineData:
        """Run a single stage."""
        idx = self._find_stage_index(stage_name)
        if idx is None:
            raise ValueError(f"Stage not found: {stage_name}")
        
        if input_data is None:
            input_data = self._load_previous_stage_output(idx)
        
        return self._run_stages(input_data, idx, idx + 1)
    
    def run_from(self, stage_name: str, input_data: PipelineData = None) -> PipelineData:
        """Run from specific stage to end."""
        idx = self._find_stage_index(stage_name)
        if idx is None:
            raise ValueError(f"Stage not found: {stage_name}")
        
        if input_data is None:
            input_data = self._load_previous_stage_output(idx)
        
        return self._run_stages(input_data, idx, len(self.stages))
    
    def run_range(self, start: str, end: str, input_data: PipelineData = None) -> PipelineData:
        """Run a range of stages (inclusive)."""
        start_idx = self._find_stage_index(start)
        end_idx = self._find_stage_index(end)
        
        if start_idx is None or end_idx is None:
            raise ValueError("Invalid stage names")
        if start_idx > end_idx:
            raise ValueError("Start must precede end")
        
        if input_data is None:
            input_data = self._load_previous_stage_output(start_idx)
        
        return self._run_stages(input_data, start_idx, end_idx + 1)
    
    def get_stage_names(self) -> List[str]:
        """List all stage names in order."""
        return [s.name for s in self.stages]
    
    def _find_stage_index(self, name: str) -> Optional[int]:
        for idx, stage in enumerate(self.stages):
            if stage.name == name:
                return idx
        return None
    
    def _load_previous_stage_output(self, idx: int) -> PipelineData:
        if idx == 0:
            raise ValueError("First stage requires input_data")
        prev_stage = self.stages[idx - 1].name
        checkpoint = self._load_checkpoint_for_stage(prev_stage)
        if not checkpoint:
            raise ValueError(f"No checkpoint for {prev_stage}")
        return PipelineData.from_dict(checkpoint['data'])
    
    def _run_stages(self, data: PipelineData, start: int, end: int) -> PipelineData:
        for idx in range(start, end):
            stage = self.stages[idx]
            try:
                if not stage.validate_input(data):
                    raise ValueError(f"Invalid input for {stage.name}")
                stage.log_start(data)
                data = stage.process(data)
                data.stage = stage.name
                data.timestamp = datetime.now().isoformat()
                stage.log_complete(data)
                self._save_checkpoint(stage.name, data)
            except Exception as e:
                stage.log_error(e, data)
                self._save_checkpoint(stage.name, data, error=str(e))
                raise
        return data
```

---

## Factory Function

Convenience function to create pre-configured pipelines.

```python
def create_immunogenicity_pipeline(config: dict) -> Pipeline:
    """Factory for immunogenicity optimization pipeline."""
    from .stages import (
        EpitopePredictionStage,
        SequenceGenerationStage,
        MHCEvaluationStage,
        StructurePredictionStage,
        InterfaceAnalysisStage,
        RankingStage
    )
    
    stages = [
        EpitopePredictionStage(config),
        SequenceGenerationStage(config),
        MHCEvaluationStage(config),
        StructurePredictionStage(config),
        InterfaceAnalysisStage(config),
        RankingStage(config)
    ]
    
    checkpoint_dir = Path(config.get('output_dir', 'results')) / 'checkpoints'
    resume = config.get('resume', False)
    
    return Pipeline(stages, checkpoint_dir=checkpoint_dir, resume=resume)


# Usage
config = {
    'mode': 'reduce',
    'max_candidates': 10,
    'output_dir': 'results'
}
pipeline = create_immunogenicity_pipeline(config)
result = pipeline.run(input_data)
```

---

## Best Practices Summary

| Aspect | Recommendation |
|--------|----------------|
| Stage granularity | One stage = one logical step |
| Data passing | Use `PipelineData.metadata` |
| Error handling | Log + checkpoint + re-raise |
| Configuration | Pass via `config` dict |
| Testing | Test stages independently |
| Resumability | Always save checkpoints |
