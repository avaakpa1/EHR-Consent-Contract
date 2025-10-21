
import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const patient1 = accounts.get("wallet_1")!;
const patient2 = accounts.get("wallet_2")!;
const hospital1 = accounts.get("wallet_3")!;
const provider1 = accounts.get("wallet_4")!;

const contractName = "EHR-Consent-Contract";

describe("EHR Consent Contract - Audit Trail Tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  describe("Basic EHR Operations", () => {
    it("should register patient EHR successfully", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "register-patient-ehr",
        [Cl.stringAscii("patient123hash")],
        patient1
      );
      expect(result).toBeOk(true);
    });

    it("should register hospital successfully", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "register-hospital",
        [Cl.stringAscii("City General Hospital")],
        hospital1
      );
      expect(result).toBeOk(true);
    });

    it("should verify hospital by deployer", () => {
      // First register the hospital
      simnet.callPublicFn(
        contractName,
        "register-hospital",
        [Cl.stringAscii("City General Hospital")],
        hospital1
      );
      
      // Then verify it
      const { result } = simnet.callPublicFn(
        contractName,
        "verify-hospital",
        [Cl.principal(hospital1)],
        deployer
      );
      expect(result).toBeOk(true);
    });
  });

  describe("Audit Trail System", () => {
    it("should create audit record successfully", () => {
      // Setup patient and hospital
      simnet.callPublicFn(contractName, "register-patient-ehr", ["patient456hash"], patient1);
      simnet.callPublicFn(contractName, "register-hospital", ["Test Hospital"], hospital1);
      simnet.callPublicFn(contractName, "verify-hospital", [hospital1], deployer);

      const { result } = simnet.callPublicFn(
        contractName,
        "create-audit-record",
        [
          "access_granted",
          patient1,
          hospital1,
          1,
          "Test audit record creation",
          "info"
        ],
        patient1
      );
      expect(result).toBeOk(1);
    });

    it("should retrieve audit record", () => {
      // Setup and create audit record
      simnet.callPublicFn(contractName, "register-patient-ehr", ["patient789hash"], patient2);
      simnet.callPublicFn(contractName, "register-hospital", ["Another Hospital"], hospital1);
      simnet.callPublicFn(contractName, "verify-hospital", [hospital1], deployer);
      
      simnet.callPublicFn(
        contractName,
        "create-audit-record",
        [
          "data_accessed",
          patient2,
          hospital1,
          2,
          "Patient data accessed for treatment",
          "info"
        ],
        patient2
      );

      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-audit-record",
        [1],
        patient2
      );
      expect(result).toBeSome();
    });

    it("should get patient audit summary", () => {
      const { result } = simnet.callReadOnlyFn(
        contractName,
        "get-patient-audit-summary",
        [patient1],
        patient1
      );
      // Should return some data after creating audit records above
      expect(result).toBeSome();
    });

    it("should flag security violation", () => {
      // Setup
      simnet.callPublicFn(contractName, "register-hospital", ["Flagging Hospital"], hospital1);
      simnet.callPublicFn(contractName, "verify-hospital", [hospital1], deployer);

      const { result } = simnet.callPublicFn(
        contractName,
        "flag-security-violation",
        [
          patient1,
          "unauthorized_access",
          "Attempted access without valid permission"
        ],
        hospital1
      );
      expect(result).toBeOk(true);
    });

    it("should generate compliance report for patient", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "generate-compliance-report",
        [
          patient1,
          "patient",
          0,
          1000
        ],
        patient1
      );
      expect(result).toBeOk();
    });

    it("should generate compliance report for hospital", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "generate-compliance-report",
        [
          hospital1,
          "hospital",
          0,
          1000
        ],
        hospital1
      );
      expect(result).toBeOk();
    });
  });

  describe("Integrated Audit Logging", () => {
    it("should create audit records when granting access", () => {
      // Setup
      simnet.callPublicFn(contractName, "register-patient-ehr", ["integration_test_hash"], patient1);
      simnet.callPublicFn(contractName, "register-hospital", ["Integration Hospital"], hospital1);
      simnet.callPublicFn(contractName, "verify-hospital", [hospital1], deployer);

      // Grant access (should create audit record automatically)
      const { result } = simnet.callPublicFn(
        contractName,
        "grant-access",
        [
          provider1,
          hospital1,
          "read",
          144
        ],
        patient1
      );
      expect(result).toBeOk();

      // Check if audit record was created
      const auditResult = simnet.callReadOnlyFn(
        contractName,
        "get-last-audit-id",
        [],
        deployer
      );
      expect(auditResult).toBeUint();
    });

    it("should create audit records when revoking access", () => {
      // Setup - grant access first
      simnet.callPublicFn(contractName, "register-patient-ehr", ["revoke_test_hash"], patient2);
      simnet.callPublicFn(contractName, "register-hospital", ["Revoke Hospital"], hospital1);
      simnet.callPublicFn(contractName, "verify-hospital", [hospital1], deployer);
      
      const grantResult = simnet.callPublicFn(
        contractName,
        "grant-access",
        [provider1, hospital1, "modify", 144],
        patient2
      );
      const tokenId = grantResult.result;

      // Revoke access (should create audit record)
      const { result } = simnet.callPublicFn(
        contractName,
        "revoke-access",
        [tokenId],
        patient2
      );
      expect(result).toBeOk(true);
    });

    it("should create audit records when accessing EHR data", () => {
      // Setup - grant access first
      simnet.callPublicFn(contractName, "register-patient-ehr", ["access_test_hash"], patient1);
      simnet.callPublicFn(contractName, "register-hospital", ["Access Hospital"], hospital1);
      simnet.callPublicFn(contractName, "verify-hospital", [hospital1], deployer);
      
      const grantResult = simnet.callPublicFn(
        contractName,
        "grant-access",
        [provider1, hospital1, "read", 1000],
        patient1
      );
      const tokenId = grantResult.result;

      // Access EHR data (should create audit record)
      const { result } = simnet.callPublicFn(
        contractName,
        "access-ehr-data",
        [tokenId],
        provider1
      );
      expect(result).toBeOk();
    });

    it("should create audit records for emergency revoke", () => {
      // Setup
      simnet.callPublicFn(contractName, "register-patient-ehr", ["emergency_test_hash"], patient2);

      // Emergency revoke (should create audit record)
      const { result } = simnet.callPublicFn(
        contractName,
        "emergency-revoke-all",
        [patient2],
        patient2
      );
      expect(result).toBeOk(true);
    });
  });

  describe("Error Handling", () => {
    it("should reject invalid event types", () => {
      simnet.callPublicFn(contractName, "register-patient-ehr", ["error_test_hash"], patient1);
      
      const { result } = simnet.callPublicFn(
        contractName,
        "create-audit-record",
        [
          "invalid_event_type",
          patient1,
          null,
          null,
          "Test invalid event",
          "info"
        ],
        patient1
      );
      expect(result).toBeErr(115); // ERR_INVALID_AUDIT_LEVEL
    });

    it("should reject invalid severity levels", () => {
      simnet.callPublicFn(contractName, "register-patient-ehr", ["severity_test_hash"], patient1);
      
      const { result } = simnet.callPublicFn(
        contractName,
        "create-audit-record",
        [
          "access_granted",
          patient1,
          null,
          null,
          "Test invalid severity",
          "invalid_severity"
        ],
        patient1
      );
      expect(result).toBeErr(115); // ERR_INVALID_AUDIT_LEVEL
    });

    it("should reject unauthorized audit access", () => {
      const { result } = simnet.callPublicFn(
        contractName,
        "create-audit-record",
        [
          "access_granted",
          patient2,  // Different patient
          null,
          null,
          "Unauthorized audit attempt",
          "info"
        ],
        patient1  // Wrong caller
      );
      expect(result).toBeErr(114); // ERR_AUDIT_ACCESS_DENIED
    });
  });
});
