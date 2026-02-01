# Testing & Debugging Reference

Patterns for testing, debugging, and optimizing protein design pipelines.

## Table of Contents

1. [Testing Strategy](#testing-strategy)
2. [Mocking External Models](#mocking-external-models)
3. [Debugging Patterns](#debugging-patterns)
4. [Performance Profiling](#performance-profiling)
5. [Common Issues & Solutions](#common-issues--solutions)
6. [Logging Best Practices](#logging-best-practices)

---

## Testing Strategy

### Unit Tests

Test individual components in isolation.

```python
import pytest
from pathlib import Path
from unittest.mock import Mock, patch

# Test data fixtures
@pytest.fixture
def sample_pdb_path(tmp_path):
    """Create a sample PDB file for testing."""
    pdb_content = """
ATOM      1  N   ALA A   1       0.000   0.000   0.000  1.00  0.00           N
ATOM      2  CA  ALA A   1       1.458   0.000   0.000  1.00  0.00           C
END
"""
    pdb_file = tmp_path / "test.pdb"
    pdb_file.write_text(pdb_content)
    return str(pdb_file)


@pytest.fixture
def sample_fasta_path(tmp_path):
    """Create a sample FASTA file for testing."""
    fasta_content = ">test_sequence\nMKLLVLGCTAAGLLLAGPAQA"
    fasta_file = tmp_path / "test.fasta"
    fasta_file.write_text(fasta_content)
    return str(fasta_file)


@pytest.fixture
def sample_config():
    """Sample pipeline configuration."""
    return {
        'mode': 'reduce',
        'epitopes_number': 5,
        'samples_per_temp': 10,
        'temperatures': [0.1, 0.3],
        'max_candidates': 5,
        'output_dir': 'test_output'
    }


# Unit test examples
class TestPipelineData:
    def test_to_dict(self):
        data = PipelineData(stage="test", metadata={'key': 'value'})
        result = data.to_dict()
        
        assert result['stage'] == "test"
        assert result['metadata']['key'] == 'value'
        assert 'timestamp' in result
    
    def test_from_dict(self):
        data_dict = {
            'stage': 'test',
            'timestamp': '2025-01-01T00:00:00',
            'metadata': {'key': 'value'}
        }
        data = PipelineData.from_dict(data_dict)
        
        assert data.stage == 'test'
        assert data.metadata['key'] == 'value'


class TestPipelineStage:
    def test_validate_input_valid(self):
        stage = SequenceGenerationStage({})
        data = PipelineData(stage="prev", metadata={'pdb_path': '/path'})
        
        assert stage.validate_input(data) is True
    
    def test_validate_input_invalid(self):
        stage = SequenceGenerationStage({})
        
        assert stage.validate_input("not_pipeline_data") is False
        assert stage.validate_input({'stage': 'test'}) is False


class TestDesignSpec:
    def test_valid_spec(self, sample_pdb_path):
        spec = DesignSpec(
            target_pdb=sample_pdb_path,
            binder_type=BinderType.NANOBODY,
            epitope_residues=[1, 2, 3]
        )
        assert spec.validate() is True
    
    def test_invalid_pdb_path(self):
        spec = DesignSpec(
            target_pdb="/nonexistent/path.pdb",
            binder_type=BinderType.NANOBODY,
            epitope_residues=[1, 2, 3]
        )
        with pytest.raises(FileNotFoundError):
            spec.validate()
    
    def test_empty_epitopes(self, sample_pdb_path):
        spec = DesignSpec(
            target_pdb=sample_pdb_path,
            binder_type=BinderType.NANOBODY,
            epitope_residues=[]
        )
        with pytest.raises(ValueError):
            spec.validate()
```

### Integration Tests

Test pipeline stages working together.

```python
class TestPipelineIntegration:
    @pytest.fixture
    def pipeline(self, sample_config):
        return create_immunogenicity_pipeline(sample_config)
    
    def test_full_pipeline_small_example(self, pipeline, sample_fasta_path, sample_pdb_path, tmp_path):
        """Test complete pipeline on small test case."""
        input_data = PipelineData(
            stage="input",
            metadata={
                'fasta_path': sample_fasta_path,
                'pdb_path': sample_pdb_path,
                'output_dir': str(tmp_path / 'results')
            }
        )
        
        # This would run with mocked models in practice
        result = pipeline.run(input_data)
        
        assert result is not None
        assert result.stage == "ranking"
        assert 'final_results' in result.metadata
    
    def test_checkpoint_resume(self, pipeline, sample_fasta_path, sample_pdb_path, tmp_path):
        """Test checkpoint and resume functionality."""
        output_dir = tmp_path / 'results'
        input_data = PipelineData(
            stage="input",
            metadata={
                'fasta_path': sample_fasta_path,
                'pdb_path': sample_pdb_path,
                'output_dir': str(output_dir)
            }
        )
        
        # Run first stage
        result = pipeline.run_stage("epitope_prediction", input_data)
        
        # Verify checkpoint exists
        checkpoint_path = output_dir / 'checkpoints' / 'checkpoint_epitope_prediction.json'
        assert checkpoint_path.exists()
        
        # Create new pipeline with resume
        resume_pipeline = create_immunogenicity_pipeline({
            **sample_config,
            'output_dir': str(output_dir),
            'resume': True
        })
        
        # Should skip epitope_prediction
        status = resume_pipeline.get_stage_status()
        assert status['epitope_prediction'] == 'completed'
```

---

## Mocking External Models

Mock expensive model calls for faster tests.

```python
from unittest.mock import Mock, patch, MagicMock


class MockStructureResult:
    """Mock structure prediction result."""
    def __init__(self, plddt: float = 85.0, sequence: str = "MKLLVL"):
        self.pdb_path = "/mock/path.pdb"
        self.sequence = sequence
        self.plddt = plddt
        self.metadata = {"model": "mock"}


class MockAlphaFoldPredictor:
    """Mock AlphaFold predictor for testing."""
    def predict(self, sequence: str, output_dir: str) -> MockStructureResult:
        return MockStructureResult(sequence=sequence)
    
    def predict_batch(self, sequences: list, output_dir: str) -> list:
        return [MockStructureResult(sequence=seq) for seq in sequences]
    
    def get_requirements(self) -> dict:
        return {"gpu": False, "min_memory_gb": 0}


# Using mocks in tests
class TestWithMockedModels:
    @patch('src.tools.alphafold3_wrapper.AlphaFold3Predictor')
    def test_structure_prediction_stage(self, mock_predictor_class):
        """Test structure prediction with mocked model."""
        # Configure mock
        mock_predictor = MockAlphaFoldPredictor()
        mock_predictor_class.return_value = mock_predictor
        
        # Run stage
        stage = StructurePredictionStage({'max_candidates': 5})
        input_data = PipelineData(
            stage="mhc_evaluation",
            metadata={
                'affinity_df': [
                    {'sequence': 'MKLLVL', 'score': 10.0},
                    {'sequence': 'MKLLGL', 'score': 20.0}
                ],
                'pdb_path': '/path/to/ref.pdb',
                'output_dir': '/tmp/test'
            }
        )
        
        result = stage.process(input_data)
        
        assert 'structure_results' in result.metadata
        assert len(result.metadata['structure_results']) == 2
    
    @patch('subprocess.run')
    def test_netmhcii_wrapper(self, mock_subprocess):
        """Test NetMHCIIpan wrapper with mocked subprocess."""
        mock_subprocess.return_value = Mock(
            returncode=0,
            stdout="# NetMHCIIpan output\n",
            stderr=""
        )
        
        wrapper = NetMHCIIpanWrapper("/mock/path")
        # Would call wrapper.predict(...) here
        
        mock_subprocess.assert_called()


# Fixtures for mock models
@pytest.fixture
def mock_model_factory():
    """Fixture that provides mock model factory."""
    with patch.object(ModelFactory, 'get_model') as mock:
        mock.return_value = MockAlphaFoldPredictor()
        yield mock


def test_pipeline_with_mocked_factory(mock_model_factory, sample_config):
    """Test pipeline with all models mocked."""
    pipeline = create_immunogenicity_pipeline(sample_config)
    # ... run tests ...
    
    # Verify factory was called
    mock_model_factory.assert_called()
```

---

## Debugging Patterns

### Verbose Logging Mode

Enable detailed logging for debugging.

```python
import logging
import sys

def setup_debug_logging(output_file: str = None):
    """Configure detailed debug logging."""
    handlers = [logging.StreamHandler(sys.stdout)]
    
    if output_file:
        handlers.append(logging.FileHandler(output_file))
    
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s - %(name)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s',
        handlers=handlers
    )
    
    # Also enable for external libraries
    logging.getLogger('torch').setLevel(logging.INFO)
    logging.getLogger('urllib3').setLevel(logging.WARNING)


# Usage
setup_debug_logging("debug.log")
```

### Stage Profiling

Profile individual stages for performance analysis.

```python
import time
from functools import wraps
from dataclasses import dataclass, field
from typing import Dict

@dataclass
class StageProfile:
    """Profile information for a stage."""
    name: str
    start_time: float = 0.0
    end_time: float = 0.0
    memory_before_mb: float = 0.0
    memory_after_mb: float = 0.0
    
    @property
    def duration(self) -> float:
        return self.end_time - self.start_time
    
    @property
    def memory_delta_mb(self) -> float:
        return self.memory_after_mb - self.memory_before_mb


class ProfiledPipeline(Pipeline):
    """Pipeline with profiling support."""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.profiles: Dict[str, StageProfile] = {}
    
    def _run_stages(self, data: PipelineData, start: int, end: int) -> PipelineData:
        for idx in range(start, end):
            stage = self.stages[idx]
            profile = StageProfile(name=stage.name)
            
            # Record start
            profile.start_time = time.time()
            profile.memory_before_mb = self._get_memory_usage()
            
            # Run stage
            data = stage.process(data)
            data.stage = stage.name
            data.timestamp = datetime.now().isoformat()
            
            # Record end
            profile.end_time = time.time()
            profile.memory_after_mb = self._get_memory_usage()
            
            self.profiles[stage.name] = profile
            self._save_checkpoint(stage.name, data)
            
            self.logger.info(
                f"Stage {stage.name}: {profile.duration:.2f}s, "
                f"memory delta: {profile.memory_delta_mb:+.1f}MB"
            )
        
        return data
    
    def _get_memory_usage(self) -> float:
        """Get current memory usage in MB."""
        import psutil
        process = psutil.Process()
        return process.memory_info().rss / 1024 / 1024
    
    def print_profile_summary(self):
        """Print profiling summary."""
        print("\n" + "=" * 60)
        print("Pipeline Profile Summary")
        print("=" * 60)
        
        total_time = sum(p.duration for p in self.profiles.values())
        
        for name, profile in self.profiles.items():
            pct = (profile.duration / total_time * 100) if total_time > 0 else 0
            print(f"  {name:30s} {profile.duration:8.2f}s ({pct:5.1f}%)")
        
        print("-" * 60)
        print(f"  {'Total':30s} {total_time:8.2f}s")
        print("=" * 60)
```

### Intermediate Output Inspection

Save and inspect intermediate outputs.

```python
class DebugPipeline(Pipeline):
    """Pipeline with intermediate output saving."""
    
    def __init__(self, *args, save_intermediates: bool = True, **kwargs):
        super().__init__(*args, **kwargs)
        self.save_intermediates = save_intermediates
        self.intermediate_dir = self.checkpoint_dir.parent / 'intermediates'
        if self.save_intermediates:
            self.intermediate_dir.mkdir(parents=True, exist_ok=True)
    
    def _run_stages(self, data: PipelineData, start: int, end: int) -> PipelineData:
        for idx in range(start, end):
            stage = self.stages[idx]
            data = stage.process(data)
            data.stage = stage.name
            
            if self.save_intermediates:
                self._save_intermediate(idx, stage.name, data)
            
            self._save_checkpoint(stage.name, data)
        
        return data
    
    def _save_intermediate(self, idx: int, stage_name: str, data: PipelineData):
        """Save intermediate output for debugging."""
        import json
        
        output_dir = self.intermediate_dir / f"{idx:02d}_{stage_name}"
        output_dir.mkdir(exist_ok=True)
        
        # Save metadata
        with open(output_dir / "metadata.json", 'w') as f:
            json.dump(data.to_dict(), f, indent=2, default=str)
        
        # Save specific outputs based on stage
        metadata = data.metadata
        
        if 'epitope_df' in metadata:
            import pandas as pd
            pd.DataFrame(metadata['epitope_df']).to_csv(
                output_dir / "epitopes.csv", index=False
            )
        
        if 'mutants' in metadata:
            with open(output_dir / "mutants.fasta", 'w') as f:
                for i, seq in enumerate(metadata['mutants']):
                    f.write(f">mutant_{i:04d}\n{seq}\n")
        
        if 'structure_results' in metadata:
            import pandas as pd
            pd.DataFrame(metadata['structure_results']).to_csv(
                output_dir / "structures.csv", index=False
            )
        
        self.logger.debug(f"Intermediate output saved: {output_dir}")
```

---

## Performance Profiling

### GPU Memory Tracking

```python
import torch

class GPUMemoryTracker:
    """Track GPU memory usage."""
    
    def __init__(self, device: int = 0):
        self.device = device
        self.snapshots = []
    
    def snapshot(self, label: str):
        """Take memory snapshot."""
        if not torch.cuda.is_available():
            return
        
        allocated = torch.cuda.memory_allocated(self.device) / 1e9
        reserved = torch.cuda.memory_reserved(self.device) / 1e9
        
        self.snapshots.append({
            'label': label,
            'allocated_gb': allocated,
            'reserved_gb': reserved,
            'timestamp': time.time()
        })
    
    def print_summary(self):
        """Print memory usage summary."""
        print("\nGPU Memory Usage:")
        for snap in self.snapshots:
            print(f"  {snap['label']:30s} "
                  f"allocated: {snap['allocated_gb']:.2f}GB, "
                  f"reserved: {snap['reserved_gb']:.2f}GB")
    
    @staticmethod
    def clear_cache():
        """Clear GPU cache."""
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.synchronize()


# Usage
tracker = GPUMemoryTracker()
tracker.snapshot("before_model_load")
model = load_model()
tracker.snapshot("after_model_load")
result = model.predict(...)
tracker.snapshot("after_inference")
tracker.print_summary()
```

### Batch Processing Optimization

```python
def find_optimal_batch_size(
    model,
    sample_input,
    max_batch_size: int = 64,
    target_memory_utilization: float = 0.8
) -> int:
    """Find optimal batch size through binary search."""
    import torch
    
    if not torch.cuda.is_available():
        return 1
    
    total_memory = torch.cuda.get_device_properties(0).total_memory
    target_memory = total_memory * target_memory_utilization
    
    low, high = 1, max_batch_size
    optimal = 1
    
    while low <= high:
        mid = (low + high) // 2
        
        try:
            torch.cuda.empty_cache()
            # Create batch of size mid
            batch = [sample_input] * mid
            
            # Run inference
            with torch.no_grad():
                _ = model.predict_batch(batch, "/tmp/test")
            
            # Check memory usage
            used_memory = torch.cuda.memory_allocated(0)
            
            if used_memory < target_memory:
                optimal = mid
                low = mid + 1
            else:
                high = mid - 1
                
        except RuntimeError as e:
            if "out of memory" in str(e):
                high = mid - 1
                torch.cuda.empty_cache()
            else:
                raise
    
    return optimal
```

---

## Common Issues & Solutions

### Issue 1: Model Loading Failures

```python
def safe_model_load(model_type: str, checkpoint: str, device: str = "cuda"):
    """Load model with comprehensive error handling."""
    import torch
    
    # Check CUDA availability
    if device.startswith("cuda") and not torch.cuda.is_available():
        logger.warning("CUDA not available, falling back to CPU")
        device = "cpu"
    
    # Check checkpoint exists
    if not Path(checkpoint).exists():
        raise FileNotFoundError(f"Checkpoint not found: {checkpoint}")
    
    # Check memory requirements
    if device.startswith("cuda"):
        requirements = {
            "alphafold3": 16,
            "rfdiffusion": 12,
            "proteinmpnn": 4
        }
        required_gb = requirements.get(model_type, 8)
        available_gb = torch.cuda.get_device_properties(0).total_memory / 1e9
        
        if available_gb < required_gb:
            raise RuntimeError(
                f"{model_type} requires {required_gb}GB GPU memory, "
                f"but only {available_gb:.1f}GB available"
            )
    
    # Load model
    try:
        return ModelFactory.get_model(model_type, checkpoint, device)
    except Exception as e:
        logger.error(f"Failed to load {model_type}: {e}")
        raise
```

### Issue 2: Inconsistent Results

```python
def set_reproducibility(seed: int = 42):
    """Set all random seeds for reproducibility."""
    import random
    import numpy as np
    import torch
    
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
        torch.backends.cudnn.deterministic = True
        torch.backends.cudnn.benchmark = False
    
    # Log the seed
    logger.info(f"Random seed set to {seed}")
    
    return seed


# Call at pipeline start
set_reproducibility(config.get('random_seed', 42))
```

### Issue 3: Memory Leaks

```python
from contextlib import contextmanager

@contextmanager
def model_inference_context():
    """Context manager to prevent memory leaks."""
    try:
        yield
    finally:
        import gc
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.synchronize()


# Usage
with model_inference_context():
    result = model.predict(sequence)
```

---

## Logging Best Practices

### Structured Logging

```python
import logging
import json
from datetime import datetime

class StructuredFormatter(logging.Formatter):
    """JSON-structured log formatter."""
    
    def format(self, record):
        log_dict = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno
        }
        
        # Add extra fields
        if hasattr(record, 'stage'):
            log_dict['stage'] = record.stage
        if hasattr(record, 'duration'):
            log_dict['duration'] = record.duration
        if hasattr(record, 'error'):
            log_dict['error'] = record.error
        
        return json.dumps(log_dict)


def setup_structured_logging(output_file: str):
    """Set up JSON-structured logging."""
    handler = logging.FileHandler(output_file)
    handler.setFormatter(StructuredFormatter())
    
    logger = logging.getLogger()
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)


# Usage in stages
class MyStage(PipelineStage):
    def process(self, input_data):
        self.logger.info(
            "Processing started",
            extra={'stage': self.name, 'input_size': len(input_data.metadata)}
        )
        
        start = time.time()
        result = self._do_work(input_data)
        
        self.logger.info(
            "Processing completed",
            extra={'stage': self.name, 'duration': time.time() - start}
        )
        
        return result
```

---

## Best Practices Summary

| Aspect | Recommendation |
|--------|----------------|
| Unit tests | Test components in isolation |
| Integration tests | Test stage interactions |
| Mocking | Mock expensive model calls |
| Fixtures | Use pytest fixtures for test data |
| Profiling | Profile before optimizing |
| Logging | Use structured logging |
| Memory | Track and clear GPU memory |
| Reproducibility | Set all random seeds |
