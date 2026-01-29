# Changelog

All notable changes and improvements to the connect-postgres-dbeaver skill.

## [1.1.0] - 2026-01-29

### Added
- **Automatic password saving in DBeaver** using CLI flags
- **Prerequisites check** in connect.sh (tsh, vault, dbeaver, jq)
- **VAULT_ADDR auto-configuration** (https://vault.maestra.io)
- **Teleport proxy specification** (--proxy=teleport.maestra.io) for all commands
- **cleanup_connections.sh** script to remove broken connections
- Comprehensive error handling and user-friendly messages
- Colored output for better readability
- Automatic cleanup of old DBeaver instances before connecting

### Fixed
- **Password not being saved in DBeaver** - now uses CLI with savePassword=true flag
- **Teleport version warnings** - added proper proxy specification
- **Multiple Teleport profiles conflict** - explicitly use teleport.maestra.io
- **Vault connection refused** - automatically set VAULT_ADDR
- **VNet not starting** - added authentication check before starting
- **Old broken connections remaining** - automatic detection and cleanup

### Improved
- All scripts now validate prerequisites before running
- Better error messages with specific solutions
- Automatic handling of expired credentials (12-hour TTL)
- Network connectivity verification with detailed output
- Connection string format for maximum compatibility

### Documentation
- Added comprehensive troubleshooting section with 10 common cases
- Documented all corner cases and their solutions
- Added best practices section
- Updated examples with real-world scenarios
- Added security notes about credential TTL and roles

## [1.0.0] - 2026-01-29

### Initial Release
- Basic database connection automation
- Teleport app discovery
- VNet management
- Vault credential retrieval
- DBeaver launch

### Known Issues (Fixed in 1.1.0)
- Password prompt appeared in DBeaver despite providing credentials
- Teleport version warnings caused confusion
- Multiple profiles could conflict
- Vault address not set automatically
- No cleanup of broken connections
