# convert

[![Model Conversion](https://github.com/ggml-org/convert/actions/workflows/main.yml/badge.svg)](https://github.com/ggml-org/convert/actions/workflows/main.yml)

Automated pipeline for converting models to GGUF format and uploading them to HF.

Supported models: [models/](models/)

## Usage

```bash
# Convert all models
HF_TOKEN=xxx bash convert.sh --owner <org>

# Convert a single model
HF_TOKEN=xxx bash convert.sh --owner <org> --one gemma-4-12b

# Convert models matching a filter
HF_TOKEN=xxx bash convert.sh --owner <org> --filter '^gemma'
```

## Notes

- Models are converted only if at least one of the source models has been updated
- All models in [ggml-org](https://huggingface.co/ggml-org) are auto-converted by a [GitHub Actions workflow](https://github.com/ggml-org/convert/actions/workflows/main.yml) once per week
  
  ```bash
  HF_TOKEN=xxx bash convert.sh --owner ggml-org
  ```

- A maintainer can start the workflow manually from the [Actions pane](https://github.com/ggml-org/convert/actions)
