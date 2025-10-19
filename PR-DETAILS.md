## Land Valuation System

### Overview
This PR introduces a comprehensive **Land Valuation System** to the existing Land Ownership Registry, enabling certified appraisers to provide professional property valuations for registered land parcels. This independent feature creates a transparent, blockchain-based valuation ecosystem that supports various use cases including taxation, insurance coverage assessment, and market analysis.

### Technical Implementation

#### Key Functions Added
- **`register-appraiser`**: Allows professionals to register as certified appraisers with license validation and fee payment
- **`renew-certification`**: Enables appraisers to extend their certification periods
- **`submit-valuation`**: Certified appraisers can submit detailed land valuations with market analysis
- **`dispute-valuation`**: Land owners can dispute valuations with documented reasoning
- **`resolve-valuation-dispute`**: Contract owner can resolve disputes and adjust appraiser reputation

#### Data Structures Added
- **`certified-appraisers`**: Stores appraiser credentials, reputation scores, and certification status
- **`land-valuations`**: Comprehensive valuation records with methodology and market data
- **`land-valuation-history`**: Maintains up to 20 historical valuations per land parcel
- **`valuation-disputes`**: Tracks disputes and their resolution status

#### Key Features
- **Certification System**: Fee-based appraiser certification with expiration dates
- **Reputation Management**: Dynamic scoring based on dispute resolution outcomes
- **Comprehensive Valuations**: Includes methodology, market conditions, and comparable properties
- **Dispute Resolution**: Owner-initiated disputes with administrative resolution
- **Historical Tracking**: Complete valuation history with average calculation capabilities

### Testing & Validation
- ✅ Contract passes `clarinet check` syntax validation
- ✅ All npm tests successful with no failures
- ✅ CI/CD pipeline configured with GitHub Actions
- ✅ Clarity v3 compliant with proper error handling constants
- ✅ Independent feature with no cross-contract dependencies

### Value Proposition
This feature enhances the land registry by:
- Creating transparent, auditable property valuations
- Establishing professional appraiser accountability
- Supporting informed decision-making for land transactions
- Enabling automated valuation-based processes (insurance, taxation)
- Building comprehensive property value histories for market analysis
