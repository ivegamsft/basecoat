# Latest Release Notes

## 4.6.1 - 2026-10-06

### Fixed

- Sanitize internal account handles and CODEOWNERS from the public mirror payload so production publication passes the forbidden-identifier guard (#3538).
- Recover held automation workflows without a cron-only dependency (#3535).
- Serialize approval sweeps and recognize completed approval races (#3542).
- Generate release-notes PRs with a valid intake contract, release-label exemption, CI-triggering token, and a single trailing newline (#3544).
- Publish 4.6.0 release notes to the latest release notes report (#3536).
