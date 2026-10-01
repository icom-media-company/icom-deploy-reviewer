# Protected review registry semantics

`manual-db-review-bindings.json` is a protected control-plane attestation. Its file hash is
pinned by the trusted validator and signed bundle metadata. For every package it binds the
exact candidate, manifest digest, substantive review fields copied from that manifest, and
the separately issued final review subject, IDs, evidence digests, roles and PASS verdicts.

The original reviewer evidence byte streams were issued outside this repository and are not
available here. Therefore this control plane does not claim to recompute those external
evidence digests. It authenticates the protected registry bytes and enforces their exact
cross-bindings; the registry is not a substitute for the original evidence archive.
