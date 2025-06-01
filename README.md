# 🏡 Land Ownership Registry with Dispute Resolution

A blockchain-based land ownership registry system built on Stacks that provides transparent, tamper-proof land title records with integrated dispute resolution mechanisms.

## 🌟 Features

- 🏠 **Land Registration**: Register land parcels with GPS coordinates and document verification
- 🔄 **Secure Transfers**: Notarized land ownership transfers via smart contracts
- ⚖️ **Dispute Resolution**: DAO-based arbitration system for land disputes
- 🛡️ **Fraud Prevention**: Immutable records prevent title fraud
- 👥 **Multi-stakeholder**: Support for owners, notaries, and arbitrators

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd land-ownership-registry
clarinet check
```

## 📋 Usage

### 🏠 Land Registration

Register a new land parcel:
```clarity
(contract-call? .Land-Ownership-Registry-with-Dispute-Resolution register-land 
  u1000 ;; size in square meters
  "40.7128,-74.0060" ;; GPS coordinates
  "abc123def456..." ;; document hash
)
```

### 🔄 Land Transfer Process

1. **Initiate Transfer** (by current owner):
```clarity
(contract-call? .Land-Ownership-Registry-with-Dispute-Resolution initiate-transfer 
  u1 ;; land ID
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 ;; new owner
  'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE ;; notary
)
```

2. **Complete Transfer** (by notary):
```clarity
(contract-call? .Land-Ownership-Registry-with-Dispute-Resolution complete-transfer u1)
```

### ⚖️ Dispute Resolution

1. **Register as Arbitrator**:
```clarity
(contract-call? .Land-Ownership-Registry-with-Dispute-Resolution register-arbitrator)
```

2. **File a Dispute**:
```clarity
(contract-call? .Land-Ownership-Registry-with-Dispute-Resolution file-dispute 
  u1 ;; land ID
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 ;; respondent
  "Fraudulent ownership claim with forged documents"
)
```

3. **Vote on Dispute** (arbitrators only):
```clarity
(contract-call? .Land-Ownership-Registry-with-Dispute-Resolution vote-on-dispute 
  u1 ;; dispute ID
  true ;; vote (true = support complainant)
)
```

### 📊 Query Functions

- `get-land-info`: Get complete land information
- `get-land-owner`: Get current owner of a land parcel
- `get-dispute-info`: Get dispute details
- `get-arbitrator-info`: Get arbitrator information
- `is-notary`: Check if address is authorized notary

## 🏗️ Contract Architecture

### Data Structures
- **Land Registry**: Core land parcel information
- **Transfer Records**: Pending and completed transfers
- **Disputes**: Active and resolved disputes
- **Arbitrators**: Registered dispute resolvers
- **Notaries**: Authorized transfer validators

### Security Features
- ✅ Owner-only transfer initiation
- ✅ Notary-validated transfers
- ✅ Staked arbitrator system
- ✅ Anti-double-voting mechanisms
- ✅ Minimum vote thresholds

## 🌍 Impact

This system addresses critical issues in land governance:
- **Reduces fraud** through immutable records
- **Increases transparency** in ownership transfers
- **Provides fair dispute resolution** via decentralized arbitration
- **Enables financial inclusion** through tokenized land assets

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

---

*Built with ❤️ for transparent land governance*
```

