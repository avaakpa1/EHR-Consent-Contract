# 🏥 EHR Consent Contract

A Clarity smart contract that empowers patients with control over their Electronic Health Records (EHR) through NFT-based access keys.

## 🔐 Overview

This contract enables patients to mint NFT-based access tokens that grant time-limited, permission-based access to their health records. Healthcare providers can access patient data only with explicit consent, and patients maintain full control over who can access their information.

## ✨ Features

- 🎫 **NFT Access Keys**: Mint unique tokens representing permission to access EHR data
- 👥 **Permission Levels**: Support for `read`, `modify`, and `admin` access levels
- ⏰ **Time-Limited Access**: All permissions expire after a specified duration
- 🚫 **Revocable Access**: Patients can revoke access at any time
- 🏥 **Hospital Registry**: Verified hospital system for trusted providers
- 📊 **Usage Tracking**: Monitor access patterns and consent history
- 🚨 **Emergency Controls**: Emergency revocation capabilities

## 🚀 Usage

### For Patients

#### Register Your EHR
```clarity
(contract-call? .EHR-Consent-Contract register-patient-ehr "your-ehr-hash")
```

#### Grant Access to a Healthcare Provider
```clarity
(contract-call? .EHR-Consent-Contract grant-access 
    'SP1HEALTHCARE-PROVIDER 
    'SP1HOSPITAL 
    "read" 
    u144) ;; 144 blocks (~24 hours)
```

#### Revoke Access
```clarity
(contract-call? .EHR-Consent-Contract revoke-access u1) ;; token-id
```

#### Emergency Revoke All Access
```clarity
(contract-call? .EHR-Consent-Contract emergency-revoke-all tx-sender)
```

### For Healthcare Providers

#### Access Patient Data
```clarity
(contract-call? .EHR-Consent-Contract access-ehr-data u1) ;; token-id
```

### For Hospitals

#### Register Hospital
```clarity
(contract-call? .EHR-Consent-Contract register-hospital "City General Hospital")
```

## 📖 Read-Only Functions

### Check Access Permissions
```clarity
(contract-call? .EHR-Consent-Contract get-access-permission u1)
```

### Verify Valid Access
```clarity
(contract-call? .EHR-Consent-Contract has-valid-access u1 'SP1PROVIDER)
```

### Get Patient Record
```clarity
(contract-call? .EHR-Consent-Contract get-patient-record 'SP1PATIENT)
```

### Check Hospital Information
```clarity
(contract-call? .EHR-Consent-Contract get-hospital-info 'SP1HOSPITAL)
```

### View Consent History
```clarity
(contract-call? .EHR-Consent-Contract get-consent-history 'SP1PATIENT 'SP1HOSPITAL)
```

### Get Active Permissions Count
```clarity
(contract-call? .EHR-Consent-Contract get-active-permissions 'SP1PATIENT)
```

## 🔧 Permission Levels

| Level | Description | Capabilities |
|-------|-------------|--------------|
| `read` | Read-only access | View patient records |
| `modify` | Read and write access | View and update records |
| `admin` | Full administrative access | All permissions |

## 🏗️ Contract Structure

### Data Maps
- **patient-records**: Maps patients to their EHR hashes
- **access-permissions**: Maps token IDs to permission details
- **hospital-registry**: Registry of verified hospitals
- **patient-consent-history**: Tracks consent patterns
- **permission-usage**: Monitors access statistics

### Error Codes
- `ERR_OWNER_ONLY (u100)`: Only contract owner can perform this action
- `ERR_NOT_TOKEN_OWNER (u101)`: Must be token owner
- `ERR_TOKEN_NOT_FOUND (u102)`: Token doesn't exist
- `ERR_UNAUTHORIZED (u103)`: Unauthorized access attempt
- `ERR_PERMISSION_DENIED (u104)`: Permission denied
- `ERR_TOKEN_EXPIRED (u105)`: Access token expired
- `ERR_INVALID_PERMISSION (u106)`: Invalid permission level
- `ERR_INVALID_DURATION (u107)`: Invalid time duration
- `ERR_PATIENT_ONLY (u108)`: Patient-only function
- `ERR_HOSPITAL_NOT_REGISTERED (u109)`: Hospital not registered/verified
- `ERR_ALREADY_EXISTS (u110)`: Record already exists

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

Check contract syntax:
```bash
clarinet check
```

## 🛡️ Security Features

- **Time-based expiration**: All access automatically expires
- **Patient-controlled revocation**: Immediate access termination
- **Hospital verification**: Only verified hospitals can receive access
- **Usage monitoring**: Track all access attempts
- **Emergency controls**: Emergency revocation capabilities

## 📈 Future Enhancements

- Integration with external EHR systems via oracles
- Multi-signature requirements for sensitive operations
- Audit trails for compliance reporting
- Fine-grained permission controls
- Cross-chain compatibility

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

---

Built with ❤️ for healthcare privacy and patient empowerment
