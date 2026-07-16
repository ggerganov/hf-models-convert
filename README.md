# convert

[![Model Conversion](https://github.com/ggml-org/convert/actions/workflows/main.yml/badge.svg)](https://github.com/ggml-org/convert/actions/workflows/main.yml)

Automated pipeline for converting models to GGUF format and uploading them to HF.

Supported models: [models/](models/)

## Usage

Requires `HF_TOKEN` with write permission to the target org.

```bash
# Convert all models
bash convert.sh --owner <org>

# Convert a single model
bash convert.sh --owner <org> --one gemma-4-12b

# Convert models matching a filter
bash convert.sh --owner <org> --filter '^gemma'

# Run via HF Jobs (cloud infrastructure)
bash hf-job.sh --owner <org>
```

## Notes

- Models are converted only if at least one of the source models has been updated
- All models in [ggml-org](https://huggingface.co/ggml-org) are auto-converted by a [GitHub Actions workflow](https://github.com/ggml-org/convert/actions/workflows/main.yml) once per week
  
  ```bash
  HF_TOKEN=xxx bash hf-job.sh --owner ggml-org
  ```

- A maintainer from the [ggml-org/hf](https://github.com/orgs/ggml-org/teams/hf) team can start the workflow manually from the [Actions pane](https://github.com/ggml-org/convert/actions/workflows/main.yml)
- The conversion uses the latest version of [llama.cpp](https://github.com/ggml-org/llama.cpp)
