# docs/archive - Abandoned directions

Designs that were explored and then rejected. They are kept because the
reasoning that killed them is worth more than the design itself: without the
document, the same idea gets proposed again and re-litigated from scratch.

Nothing here describes how the system works. If you are looking for current
behavior, `docs/ARCHITECTURE.md` is the entry point.

## Files

`zero-llm-redesign.md` proposed removing the external LLM call from the Stop
hook, motivated by 2-5 seconds of latency and roughly 1.8K tokens per session.
It was tried and it degraded memory quality. `AGENTS.md` now carries the
conclusion as a standing rule: do not remove LLM extraction or automatic
capture to save cost. Read this document before proposing anything in that
direction again, because the cost argument in it is sound and the quality
outcome is what settled the question.
