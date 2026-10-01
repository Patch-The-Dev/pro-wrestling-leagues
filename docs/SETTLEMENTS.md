# Match settlement protocol

## Ownership

`MatchCoordinator` decides whether a finished match is eligible. `EconomyService` snapshots its reward policy and records the result. `MatchSettlementJournal` owns recovery after that durable handoff. `PlayerRepository` owns profile mutation and saved-data confirmation.

The two player profiles are separate storage records. The journal reconciles their completion rather than assuming both writes succeed together.

## Stored records

| Record | Fields | Lifetime |
| --- | --- | --- |
| `result/{matchId}` | Participants, finish time, original reward amounts | Until both profile saves are acknowledged, or the pair cooldown rejects the result |
| `pair/{lowerUserId}:{higherUserId}` | Sequence, last accepted match/time, optional pending match and two save acknowledgements | Retained to coordinate cooldown and sequence ordering |
| Profile `MatchRewardSequences[opponentId]` | Last applied sequence for this opponent | Retained for permanent replay protection |
| Profile `Statistics.RecentMatchIds` | Most recent 64 rewarded match IDs | Bounded inspection history, independent of replay protection |

Schema 5 adds the watermark map without changing the existing player datastore name. It is omitted from client snapshots. Studio uses separate in-memory settlement records and mock ProfileStore sessions.

## Completion sequence

1. Write the immutable result intent with `UpdateAsync`. A retry preserves the original amounts. Reusing the ID for another result is rejected.
2. Atomically check the opponent cooldown and assign the next pair sequence with a pending result. A pending match cannot be replaced by another claim.
3. Apply a participant's reward only when its profile watermark is the preceding sequence. An already applied sequence is accepted without changing balances. A missing earlier sequence remains pending.
4. Request a profile save. Success means saved profile data contains the required watermark, not merely that `Save()` was called.
5. Acknowledge that participant in the pair record. Clear the pending state only after both acknowledgements.
6. Read the authoritative pair state through `UpdateAsync`, then remove the completed result record.

The watermark and balances change synchronously in the same profile, before a save is requested. Invalid amounts and balance overflow are checked before mutation.

## Failure handling

| Failure | Response |
| --- | --- |
| Initial result write fails | Coordinator retries with capped backoff; result handoff remains incomplete |
| Pair claim fails | Recorded result remains available for recovery |
| One participant is offline | Save the available side; retain the other side until its profile is loaded |
| Save throws, session ends, or confirmation times out | Do not acknowledge that side; retry later |
| Save succeeds but acknowledgement fails | Replay observes the saved watermark and acknowledges without paying again |
| A write commits but its response is lost | Retry the same match and sequence; no new reward identity is created |
| Server exits after recording the result | Another server's recovery scan resumes the stored result |
| Final removal fails | A later pass observes completed pair state and retries removal |

A callback waits at most `PersistenceConfig.SaveConfirmationSeconds`. The scan processes one page of `MatchConfig.SettlementPageSize` records per pass, separated by `SettlementScanSeconds`. It advances through the listing rather than repeatedly examining only the first page. Pair writes are skipped when neither participant has a loaded profile on that server.

Shutdown has one bounded handoff wait. An already recorded result survives that deadline. If storage never accepts the initial result before the entire server disappears, no storage-backed system can recover an unwritten outcome; the failed handoff is logged rather than described as completed.

## Operations

- Monitor failed result writes, pending settlement warnings, recovery scan errors, and save confirmation timeouts.
- Use the logged match ID to inspect its `result/` record and corresponding `pair/` record.
- Compare each participant's saved opponent watermark with the pending sequence before any repair.
- Keep pair sequence records and profile watermarks when maintaining old match history. Deleting or resetting them changes replay protection.
- Track pending record volume and scan latency as player count grows. Page size and scan interval bound per-server work; they do not promise a fixed recovery time for an arbitrarily large backlog.
- Test changes to reward policy with pending records present. Existing records keep the original amounts.

## Verification

The unit suite covers partial settlement across replacement journal instances, unavailable storage, a lost acknowledgement response after a committed write, pair ordering and cooldown, offline profiles, paginated recovery, fixed reward amounts, and replay after more than 64 matches.

The two-client Studio suite uses the production game entrypoints, actual networking and match lifecycle, and mock ProfileStore save events. It confirms both saved watermarks, verifies that reprocessing the completed match cannot pay again, and checks that both real client controllers receive match completion. Unhandled application errors on either client or the server fail the suite.
