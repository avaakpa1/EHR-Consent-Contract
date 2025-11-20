import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const patient1 = accounts.get("wallet_1")!;
const hospital1 = accounts.get("wallet_3")!;
const provider1 = accounts.get("wallet_4")!;

const contractName = "EHR-Consent-Contract";

describe("EHR Consent Contract - Audit Trail Feature", () => {
  it("should initialize simnet correctly", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("should register patient EHR", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "register-patient-ehr",
      [Cl.stringAscii("patient_hash_123")],
      patient1
    );
    expect(result).toBeOk(Cl.bool(true));
  });

  it("should register and verify hospital", () => {
    // Register hospital
    const registerResult = simnet.callPublicFn(
      contractName,
      "register-hospital",
      [Cl.stringAscii("Test Hospital")],
      hospital1
    );
    expect(registerResult.result).toBeOk(Cl.bool(true));

    // Verify hospital
    const verifyResult = simnet.callPublicFn(
      contractName,
      "verify-hospital",
      [Cl.principal(hospital1)],
      deployer
    );
    expect(verifyResult.result).toBeOk(Cl.bool(true));
  });

  it("should create audit record", () => {
    // Setup
    simnet.callPublicFn(
      contractName,
      "register-patient-ehr",
      [Cl.stringAscii("audit_test_hash")],
      patient1
    );

    const { result } = simnet.callPublicFn(
      contractName,
      "create-audit-record",
      [
        Cl.stringAscii("access_granted"),
        Cl.principal(patient1),
        Cl.some(Cl.principal(hospital1)),
        Cl.some(Cl.uint(1)),
        Cl.stringAscii("Test audit record"),
        Cl.stringAscii("info")
      ],
      patient1
    );
    expect(result).toBeOk(Cl.uint(1));
  });

  it("should retrieve audit record", () => {
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-audit-record",
      [Cl.uint(1)],
      patient1
    );
    expect(result).toBeSome();
  });

  it("should get last audit ID", () => {
    const { result } = simnet.callReadOnlyFn(
      contractName,
      "get-last-audit-id",
      [],
      deployer
    );
    expect(result).toBeUint(1);
  });

  it("should grant access and create audit trail", () => {
    // Grant access
    const grantResult = simnet.callPublicFn(
      contractName,
      "grant-access",
      [
        Cl.principal(provider1),
        Cl.principal(hospital1),
        Cl.stringAscii("read"),
        Cl.uint(144)
      ],
      patient1
    );
    expect(grantResult.result).toBeOk();

    // Check if audit ID increased
    const auditIdResult = simnet.callReadOnlyFn(
      contractName,
      "get-last-audit-id",
      [],
      deployer
    );
    expect(auditIdResult.result).toBeGreaterThan(Cl.uint(1));
  });

  it("should generate compliance report", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "generate-compliance-report",
      [
        Cl.principal(patient1),
        Cl.stringAscii("patient"),
        Cl.uint(0),
        Cl.uint(1000)
      ],
      patient1
    );
    expect(result).toBeOk();
  });

  it("should reject invalid event types", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "create-audit-record",
      [
        Cl.stringAscii("invalid_event"),
        Cl.principal(patient1),
        Cl.none(),
        Cl.none(),
        Cl.stringAscii("Test invalid"),
        Cl.stringAscii("info")
      ],
      patient1
    );
    expect(result).toBeErr(Cl.uint(115)); // ERR_INVALID_AUDIT_LEVEL
  });

  it("should reject invalid severity levels", () => {
    const { result } = simnet.callPublicFn(
      contractName,
      "create-audit-record",
      [
        Cl.stringAscii("access_granted"),
        Cl.principal(patient1),
        Cl.none(),
        Cl.none(),
        Cl.stringAscii("Test invalid severity"),
        Cl.stringAscii("invalid_level")
      ],
      patient1
    );
    expect(result).toBeErr(Cl.uint(115)); // ERR_INVALID_AUDIT_LEVEL
  });
});
