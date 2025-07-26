# Carbon Credit Token (CCT) Smart Contract

A comprehensive smart contract for managing carbon credits on the Stacks blockchain, enabling transparent tracking, trading, and retirement of carbon offset credits.

## Overview

The Carbon Credit Token (CCT) contract implements a fungible token standard specifically designed for carbon credits. It provides functionality for minting verified carbon credits, transferring them between parties, and permanently retiring them to claim carbon offsets.

## Features

### Core Token Functionality
- **ERC-20 Compatible**: Standard token operations (transfer, approve, allowance)
- **Minting**: Create new carbon credits with detailed metadata
- **Retirement**: Permanently burn credits to claim carbon offsets
- **Batch Operations**: Efficient batch transfers

### Carbon Credit Specific Features
- **Project Tracking**: Each credit is linked to a specific carbon offset project
- **Vintage Year**: Credits include the year the carbon reduction occurred
- **Methodology**: Tracks the carbon accounting methodology used
- **Verification**: Only authorized verifiers can mint new credits
- **Retirement Tracking**: Permanent record of retired credits per user

### Security & Administration
- **Access Control**: Owner and verifier authorization system
- **Contract Pausing**: Emergency pause functionality
- **Input Validation**: Comprehensive validation of all inputs
- **Error Handling**: Detailed error codes for debugging

## Contract Details

- **Token Name**: Carbon Credit Token
- **Token Symbol**: CCT
- **Decimals**: 6
- **Blockchain**: Stacks

## Key Functions

### Token Operations
```clarity
;; Transfer tokens
(transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))

;; Approve spending allowance
(approve (spender principal) (amount uint))

;; Transfer from approved allowance
(transfer-from (amount uint) (sender principal) (recipient principal))
```

### Carbon Credit Management
```clarity
;; Mint new carbon credits (verifiers only)
(mint-carbon-credits (recipient principal) (amount uint) (project-id (string-ascii 64)) 
                     (vintage uint) (methodology (string-ascii 32)) (verification-body (string-ascii 32)))

;; Retire credits permanently
(retire-credits (amount uint))

;; Batch transfer multiple recipients
(batch-transfer (transfers (list 10 {recipient: principal, amount: uint})))
```

### Administrative Functions
```clarity
;; Add/remove authorized verifiers (owner only)
(add-verifier (verifier principal))
(remove-verifier (verifier principal))

;; Pause/unpause contract (owner only)
(set-contract-paused (paused bool))
```

## Read-Only Functions

- `get-balance`: Check token balance for an address
- `get-token-metadata`: Retrieve detailed credit information
- `get-project-total`: Total credits issued for a project
- `get-retired-credits`: Credits retired by a user
- `is-contract-paused`: Check if contract is paused

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100 | ERR_UNAUTHORIZED | Caller lacks required permissions |
| 101 | ERR_INSUFFICIENT_BALANCE | Insufficient token balance |
| 102 | ERR_INVALID_AMOUNT | Invalid amount (must be > 0) |
| 103 | ERR_TOKEN_NOT_FOUND | Token ID does not exist |
| 104 | ERR_ALREADY_RETIRED | Credit already retired |
| 105 | ERR_INVALID_RECIPIENT | Invalid recipient address |
| 106 | ERR_TRANSFER_FAILED | Transfer operation failed |
| 107 | ERR_INVALID_PRINCIPAL | Invalid principal address |
| 108 | ERR_INVALID_STRING | Invalid string parameter |

## Usage Examples

### Minting Carbon Credits
Only authorized verifiers can mint new credits:
```clarity
(contract-call? .carbon-credit-token mint-carbon-credits 
  'SP1234567890... ;; recipient
  u1000000        ;; amount (1 tonne CO2 with 6 decimals)
  "PROJ-001"      ;; project ID
  u2024           ;; vintage year
  "VCS"           ;; methodology
  "VERIFIER-A"    ;; verification body
)
```

### Transferring Credits
```clarity
(contract-call? .carbon-credit-token transfer 
  u500000         ;; amount (0.5 tonnes)
  tx-sender       ;; sender
  'SP9876543210... ;; recipient
  none            ;; memo
)
```

### Retiring Credits
```clarity
(contract-call? .carbon-credit-token retire-credits u1000000)
```

## Security Considerations

1. **Authorized Verifiers**: Only trusted entities should be granted verifier status
2. **Project Validation**: Verify project IDs correspond to real carbon offset projects
3. **Double Counting**: Ensure credits aren't double-counted across different systems
4. **Retirement Permanence**: Retired credits cannot be recovered or transferred
