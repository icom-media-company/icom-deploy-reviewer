# Mint idempotency contract

The exact candidate SHA, reviewed control SHA and canonical Ed25519 signer identify one
logical authorization. The workflow reserves that identity with an exact tag and draft
release before the signing secret is accessed.

Ed25519 signing is deterministic for identical key, namespace and input bytes. Package and
metadata inputs contain no runtime timestamps or run IDs. The archive builder fixes member
order, uid/gid, names, modes, mtimes and gzip metadata. Therefore a crash after reservation
but before recoverable staging may regenerate bytes only after proving the same canonical
signing public key; all four manifest signatures, metadata signature, inventory and archive
digest must be identical. A verified staging artifact is recovered without signing. An
existing malformed or unverifiable staging artifact fails closed.

Partial-state recovery is also deterministic: an exact tag without a release is completed
to the same draft reservation; a draft with zero assets resumes the byte-identical mint; a
draft with exactly the two expected, cryptographically verified assets is published without
signing or re-upload. One, extra, wrongly named, or invalid assets fail closed. Every upload
is re-downloaded and fully verified while the release is still draft, before publication.

Draft releases are discovered from the authenticated, paginated releases collection by an
exact unique `tag_name`; GitHub's release-by-tag endpoint does not expose drafts. After
discovery or REST creation, every release read, asset transfer and edit is bound to the
numeric release ID. An exact tag-only crash state creates the missing draft reservation and
continues the same idempotent identity; it never deletes the tag or reservation.

The pre-sign reservation at release ID `400681564` belongs to control
`b589d4d92200ac393a04344f2f203efe7f177e6a`, whose draft discovery failed with a 404.
The active workflow verifies that legacy release and tag ref are exact, empty and unsigned,
then leaves them untouched. It creates a distinct reservation under the new reviewed control
identity. The signed bundle contains `LEGACY-RESERVATION-SUPERSESSION.json`, binding the old
ID/tag/control and the new control. This is governed supersession, not recovery or deletion
of the legacy reservation.

Before supersession, the workflow downloads and pins attempt-1 run JSON, jobs JSON and logs
ZIP for run `36821369400`, the cancelled attempt 2, and both earlier trusted runs
`36816248037` and `36821338542` with their jobs. Those earlier runs are proven effectively
validation-only: each mint job was skipped and had no steps. The evidence proves mint job
`110237504710` failed during reservation discovery, while signing and staging were skipped.
GitHub Release `created_at` is a commit timestamp and is never treated as object creation or
as a cutoff. Instead, the proof uses `updated_at` inside the failed step window, exact bot
author, an emitted untagged URL exactly equal to live `html_url`, subsequent HTTP 404, exact
release ID/tag/body/ref, and empty durable assets. The claim deliberately does not assert
absolute historical `prior_signing=false`. Raw logs are not bundled. GitHub may regenerate
the logs ZIP with different archive metadata, ordering, or compression, so authorization
does not pin the raw ZIP bytes. It requires an exact safe regular-file census and records a
canonical digest over each ordered entry name, uncompressed byte length and SHA-256 in signed
`LEGACY-RUN-EVIDENCE.json`. Metadata-only ZIP differences therefore remain equivalent, while
changed content, renamed entries, missing entries, extra entries, links, devices and unsafe
paths fail closed without propagating operational logs.

At supersession time, an exhaustive paginated Actions census is filtered by the exact trusted
workflow ID/path and old control SHA. It must contain exactly runs `36816248037` attempt 1,
`36821338542` attempt 1, and `36821369400` with verified attempts 1 and 2. Any additional or
omitted old-control run fails closed. The canonical census and its digest are included in the
signed evidence; this census is identity-based and never uses `created_at` as a cutoff.
