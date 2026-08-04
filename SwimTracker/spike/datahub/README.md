# Data Hub unofficial pull spike

Research spike for importing USA Swimming times into SwimTracker via the Data Hub SPA’s unofficial `times-api`.

| File | Purpose |
|------|---------|
| [CONTRACT.md](CONTRACT.md) | Auth headers, endpoints, response shapes, SwimTracker field map |
| [GO_NOGO.md](GO_NOGO.md) | Recommendation: PB-only GO; full history NO-GO without login |
| [pull_times.py](pull_times.py) | Local script: search athlete → pull PBs → typed structs |
| [samples/](samples/) | Captured JSON examples |

```bash
python3 pull_times.py --name Smith --lsc AD
python3 pull_times.py --member-id 7F23E4EC26C844 --json /tmp/out.json
```
