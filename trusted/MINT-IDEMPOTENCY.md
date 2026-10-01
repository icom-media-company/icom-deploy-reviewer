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
