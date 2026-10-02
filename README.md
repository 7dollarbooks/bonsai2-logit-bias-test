# −2 logit bias on Bonsai 2 27B (RTX 5060 Laptop)

Date: 2026-10-02  
Result: on a fixed 50-question MATH-500 sample, a −2 logit bias on “wait”, “maybe”, and “perhaps” changed accuracy from 44/50 to 43/50 and average length from 845.2 to 872.3 tokens. Tokens per second stayed 29.3. This does not reproduce the Qwen3.5-4B report of higher accuracy and fewer tokens.

Suggested post title: `−2 logit bias on Bonsai 2 27B: 44/50 → 43/50 on MATH-500, +3% tokens`

## Reproduction record

| Field | Value |
| --- | --- |
| Date | 2026-10-02 |
| Model file | `Ternary-Bonsai-2-27B-PTQ1_0.gguf` |
| Model size | 5.53 GiB, 26.90 B params, 1.75 bpw ternary, group 128 |
| Model repo | https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf |
| Fork | https://github.com/PrismML-Eng/llama.cpp |
| Release | `prism-b10743-adfffbe` (2026-09-25) |
| Build | `adfffbe41` (10743). Server fingerprint `b10743-adfffbe41` |
| Windows assets | `llama-prism-b10743-adfffbe-bin-win-cuda-13.3-x64.zip` and `cudart-llama-bin-win-cuda-13.3-x64.zip` |
| GPU | NVIDIA GeForce RTX 5060 Laptop, Blackwell, compute capability 12.0, 8123 MiB |
| Driver | Game Ready 617.14 notebook, CUDA user-mode 13.4. Power max limit 85 W, NitroSense Turbo, on AC. Load temperature about 76°C |
| Context | 4096 (`-c 4096`) |
| GPU layers | `-ngl 99`, flash attention `-fa on`. Weights resident at 6508 MiB |
| Sampling, both arms | `--temp 0 --top-k 40 --top-p 0.95 --min-p 0 --seed 42` |
| Reasoning | `--reasoning-budget 2048` (Prism’s Medium cap). Generation cap `-n 3072`. Parallel 1 |
| Benchmark | HuggingFaceH4/MATH-500, 50 questions, one shared order |
| Score | Last `\boxed{}` span, then strip whitespace, `\left`, `\right`, and backticks. Exact match against the dataset `answer`. A truncated reply scores 0 |

Run A is the server above with no logit bias. Run B is the same server plus:

```text
--logit-bias 11158-2 --logit-bias 3655-2 --logit-bias 13784-2 --logit-bias 35542-2 --logit-bias 6970-2 --logit-bias 20734-2 --logit-bias 63068-2 --logit-bias 8106-2 --logit-bias 30442-2
```

| Form | Token id |
| --- | ---: |
| wait | 11158 |
| ` wait` | 3655 |
| Wait | 13784 |
| maybe | 35542 |
| ` maybe` | 6970 |
| Maybe | 20734 |
| perhaps | 63068 |
| ` perhaps` | 8106 |
| Perhaps | 30442 |

Each form was one token (`/tokenize`, `add_special=false`, `with_pieces=true`). The bias is −2, not a ban.

Prompt, both arms:

```text
Solve this problem. Put the final answer in \boxed{}.

<problem>
```

Question order: .NET `Random(42)` shuffle of the 500-row test split, first 50, saved as `questions-50.json` and reused for run B. Runner: `run_math500.ps1` in this folder.

Prism’s published thinking recipe is temperature 1.0, top-k 20, min-p 0.05. Their benchmark tables used min-p 0.0. This test holds temperature 0 so the bias is the only difference. These accuracy numbers are not a Prism leaderboard row.

## Results

| Run | n | correct | accuracy | avg completion tokens | avg tokens/s | truncations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A baseline | 50 | 44 | 88% | 845.2 | 29.27 | 2 |
| B −2 hedge bias | 50 | 43 | 86% | 872.3 | 29.28 | 2 |

Accuracy −2 points. Length +3.2% (845.2 → 872.3). Speed unchanged.

Forty-seven outcomes matched. Three changed:

| Question | A | B |
| --- | --- | --- |
| precalculus/1199 | wrong, truncated at 3072 | correct, 2221 tokens |
| prealgebra/1733 | correct, 2285 tokens | wrong, truncated at 3072 |
| precalculus/441 | correct, 2308 tokens | wrong, 1852 tokens |

Misses that stayed misses: `number_theory/598`, `algebra/2253`, `prealgebra/1742`, `intermediate_algebra/662`, `intermediate_algebra/1454`.

Per question, completion tokens. A `t` marks a reply that hit the 3072 cap.

| # | id | A | B |
| ---: | --- | ---: | ---: |
| 1 | test/precalculus/1201.json | 1631 | 2413 |
| 2 | test/algebra/849.json | 85 | 85 |
| 3 | test/precalculus/801.json | 2394 | 2381 |
| 4 | test/number_theory/598.json | 729 | 729 |
| 5 | test/intermediate_algebra/623.json | 1260 | 1276 |
| 6 | test/geometry/967.json | 156 | 162 |
| 7 | test/algebra/2264.json | 494 | 498 |
| 8 | test/algebra/2253.json | 279 | 279 |
| 9 | test/number_theory/1257.json | 485 | 485 |
| 10 | test/precalculus/1313.json | 1765 | 1988 |
| 11 | test/counting_and_probability/1114.json | 194 | 194 |
| 12 | test/intermediate_algebra/1247.json | 1522 | 1978 |
| 13 | test/geometry/483.json | 379 | 378 |
| 14 | test/prealgebra/1742.json | 204 | 204 |
| 15 | test/intermediate_algebra/662.json | 3072 t | 2886 |
| 16 | test/number_theory/427.json | 473 | 473 |
| 17 | test/prealgebra/1733.json | 2285 | 3072 t |
| 18 | test/intermediate_algebra/1454.json | 2395 | 3072 t |
| 19 | test/algebra/1332.json | 192 | 192 |
| 20 | test/precalculus/986.json | 817 | 813 |
| 21 | test/prealgebra/1640.json | 446 | 446 |
| 22 | test/algebra/346.json | 127 | 127 |
| 23 | test/prealgebra/192.json | 160 | 160 |
| 24 | test/precalculus/1199.json | 3072 t | 2221 |
| 25 | test/algebra/2232.json | 210 | 210 |
| 26 | test/algebra/1457.json | 314 | 314 |
| 27 | test/algebra/1072.json | 449 | 449 |
| 28 | test/counting_and_probability/430.json | 1119 | 1119 |
| 29 | test/number_theory/691.json | 147 | 147 |
| 30 | test/algebra/2476.json | 261 | 261 |
| 31 | test/counting_and_probability/525.json | 1416 | 1496 |
| 32 | test/geometry/353.json | 263 | 262 |
| 33 | test/precalculus/1105.json | 108 | 106 |
| 34 | test/algebra/170.json | 277 | 272 |
| 35 | test/algebra/769.json | 160 | 162 |
| 36 | test/prealgebra/1558.json | 254 | 291 |
| 37 | test/precalculus/441.json | 2308 | 1852 |
| 38 | test/intermediate_algebra/834.json | 615 | 615 |
| 39 | test/intermediate_algebra/1837.json | 387 | 386 |
| 40 | test/number_theory/1002.json | 929 | 929 |
| 41 | test/counting_and_probability/14.json | 2138 | 2130 |
| 42 | test/algebra/1004.json | 129 | 129 |
| 43 | test/precalculus/1146.json | 2505 | 2243 |
| 44 | test/algebra/2046.json | 344 | 344 |
| 45 | test/prealgebra/1995.json | 282 | 282 |
| 46 | test/precalculus/541.json | 316 | 316 |
| 47 | test/prealgebra/1572.json | 200 | 184 |
| 48 | test/algebra/1837.json | 1011 | 1011 |
| 49 | test/geometry/1140.json | 989 | 989 |
| 50 | test/geometry/795.json | 513 | 604 |

## Files in this repository

| File | Contents |
| --- | --- |
| `run_math500.ps1` | The script that sent the 50 questions |
| `questions-50.json` | The 50 problems, in order |
| `token-ids.csv` | Hedge-word token ids |
| `results-A.csv`, `results-B.csv` | Per-question scores |
| `summary-A.txt`, `summary-B.txt` | One-line summaries |
| `raw-A/`, `raw-B/` | Each reply, `01.json` through `50.json` |
| `server-A.log`, `server-B.log` | llama-server logs |

## What this is not

A LocalLLaMA report on Qwen3.5-4B saw higher MATH-500 accuracy and fewer tokens from a −2 bias on these words. The paper “Wait, We Don’t Need to ‘Wait’!” shortened traces and held accuracy, and it did not use a flat −2 bias. A −2 bias only makes the tokens less likely.

Simon Willison’s 20–44 tokens/s figures are Apple Silicon. This run is a Windows laptop at about 30 tokens/s while answering, and 31.69 tokens/s on `llama-bench` TG128.

## Separate speed row

`llama-bench` on the same file, same GPU, same day, AC power, 85 W cap:

```text
.\llama-bench.exe -m C:\Qu_models\bonsai\Ternary-Bonsai-2-27B-PTQ1_0.gguf -p 512 -n 128 -ngl 99 -fa 1
```

| Test | tokens/s |
| --- | ---: |
| pp512 | 711.71 ± 15.69 |
| tg128 | 31.69 ± 0.13 |

The bench line names the architecture inside the GGUF as `qwen35 27B PTQ1_0`. The file is `Ternary-Bonsai-2-27B-PTQ1_0.gguf`. `PQ2_0` was not tested. This row is for Prism’s community-benchmarks page, not for the logit-bias thread. There is no RTX 5060 Laptop entry in that table. Template: https://github.com/PrismML-Eng/Bonsai-demo/blob/main/community-benchmarks/bonsai2/TEMPLATE-llama-cpp.md

