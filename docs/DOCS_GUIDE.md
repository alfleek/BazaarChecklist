# Documentation guide

This file defines how project docs should be interpreted and maintained.

## Precedence (when docs conflict)

Use this order of authority:

1. [PRODUCT.md](PRODUCT.md)
2. [ARCHITECTURE.md](ARCHITECTURE.md)
3. [DATA_MODEL.md](DATA_MODEL.md)
4. [AI_CODING.md](AI_CODING.md)
5. [ROADMAP.md](ROADMAP.md)

If two docs conflict, follow the higher-precedence doc and update lower-precedence docs to match.

## Which doc to update

- Update [PRODUCT.md](PRODUCT.md) when scope, MVP/stretch status, goals, constraints, or non-goals change.
- Update [ARCHITECTURE.md](ARCHITECTURE.md) when system flows, boundaries, or integration patterns change.
- Update [DATA_MODEL.md](DATA_MODEL.md) when collection names, field shapes, enums, sync behavior, or security intent changes.
- Update [AI_CODING.md](AI_CODING.md) when implementation conventions, testing expectations, or coding workflow changes.
- Update [ROADMAP.md](ROADMAP.md) when phase order, exit criteria, or milestone commitments change.

## Update protocol

When implementing a feature:

1. Confirm behavior is in [PRODUCT.md](PRODUCT.md).
2. Update design/data docs first if needed.
3. Implement code.
4. Reconcile docs that are lower precedence so no contradictions remain.

## Scope guardrails

- Do not add new product scope in implementation docs.
- Do not change collection names casually; they are lock-sensitive for Firebase rules and clients.
- Keep mobile/web parity expectations aligned unless [PRODUCT.md](PRODUCT.md) explicitly allows a gap.
