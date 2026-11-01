
import { initializeApp } from "firebase-admin/app";
import {
  getFirestore,
  Timestamp,
  type DocumentData,
} from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";

initializeApp();

const db = getFirestore();

const TIME_ZONE = "Asia/Dhaka";
const DUE_DAY = 10;

const PROPERTY_COLLECTION = "properties";
const UNIT_COLLECTION = "units";
const TENANT_COLLECTION = "tenants";
const TENANCY_HISTORY_COLLECTION = "tenancyHistories";
const BILLING_RULE_COLLECTION = "billingRules";
const RENT_RATE_COLLECTION = "rentRates";
const MONTHLY_BILL_COLLECTION = "monthlyBills";
const MONTHLY_RENT_COLLECTION = "monthlyRents";

type DateParts = {
  year: number;
  month: number;
  day: number;
};

type BillingTarget = {
  floorId: string;
  unitId: string;
  tenantId: string;
  tenantUserId: string | null;
  tenancyHistoryId: string | null;
  tenancyStart: Date;
  tenancyEnd: Date;
};

type BillingRule = {
  id: string;
  ownerId: string;
  propertyId: string;
  scopeType: "property" | "floor" | "unit" | "tenant";
  scopeId: string;
  chargeType:
    | "water"
    | "gas"
    | "garbage"
    | "serviceCharge"
    | "electricity"
    | "other";
  valueType: "fixed" | "variable";
  amount: number;
  title: string | null;
  effectiveFrom: Date;
  effectiveTo: Date | null;
  isActive: boolean;
};

type RentRate = {
  id: string;
  ownerId: string;
  propertyId: string;
  unitId: string;
  amount: number;
  effectiveFrom: Date;
  effectiveTo: Date | null;
};

type RentSegment = {
  rate: RentRate;
  start: Date;
  end: Date;
};

const CHARGE_TYPES = [
  "water",
  "gas",
  "garbage",
  "serviceCharge",
  "electricity",
  "other",
] as const;

// ============================================================================
// BANGLADESH DATE HELPERS
// ============================================================================

function getDhakaDateParts(date: Date): DateParts {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: TIME_ZONE,
    year: "numeric",
    month: "numeric",
    day: "numeric",
  }).formatToParts(date);

  const getPart = (type: string): number => {
    const value = parts.find((part) => part.type === type)?.value;

    if (!value) {
      throw new Error(`Unable to resolve date part: ${type}`);
    }

    return Number(value);
  };

  return {
    year: getPart("year"),
    month: getPart("month"),
    day: getPart("day"),
  };
}

/**
 * Creates midnight of a Bangladesh calendar date.
 *
 * Bangladesh is UTC+06:00.
 * The returned Date is the actual UTC instant corresponding
 * to midnight in Asia/Dhaka.
 */
function dhakaDate(
  year: number,
  month: number,
  day: number,
): Date {
  return new Date(
    Date.UTC(year, month - 1, day) - 6 * 60 * 60 * 1000,
  );
}

function dateOnly(date: Date): Date {
  const parts = getDhakaDateParts(date);

  return dhakaDate(
    parts.year,
    parts.month,
    parts.day,
  );
}

function monthStart(date: Date): Date {
  const parts = getDhakaDateParts(date);

  return dhakaDate(
    parts.year,
    parts.month,
    1,
  );
}

function nextMonthStart(date: Date): Date {
  const parts = getDhakaDateParts(date);

  return dhakaDate(
    parts.year,
    parts.month + 1,
    1,
  );
}

function formatDate(date: Date): string {
  const parts = getDhakaDateParts(date);

  const year = parts.year.toString().padStart(4, "0");
  const month = parts.month.toString().padStart(2, "0");
  const day = parts.day.toString().padStart(2, "0");

  return `${year}-${month}-${day}`;
}

function formatPeriod(date: Date): string {
  const parts = getDhakaDateParts(date);

  const year = parts.year.toString().padStart(4, "0");
  const month = parts.month.toString().padStart(2, "0");

  return `${year}-${month}`;
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 86400000);
}

function daysBetweenInclusive(
  start: Date,
  end: Date,
): number {
  const startParts = getDhakaDateParts(start);
  const endParts = getDhakaDateParts(end);

  const startUtc = Date.UTC(
    startParts.year,
    startParts.month - 1,
    startParts.day,
  );

  const endUtc = Date.UTC(
    endParts.year,
    endParts.month - 1,
    endParts.day,
  );

  return Math.floor(
    (endUtc - startUtc) / 86400000,
  ) + 1;
}

function sameCalendarDate(
  first: Date,
  second: Date,
): boolean {
  return formatDate(first) === formatDate(second);
}

function minDate(first: Date, second: Date): Date {
  return first.getTime() <= second.getTime()
    ? first
    : second;
}

function maxDate(first: Date, second: Date): Date {
  return first.getTime() >= second.getTime()
    ? first
    : second;
}

function roundCurrency(value: number): number {
  return Math.round(value * 100) / 100;
}

// ============================================================================
// FIRESTORE READ HELPERS
// ============================================================================

function requiredString(
  data: DocumentData,
  field: string,
  documentId: string,
): string {
  const value = data[field];

if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(
      `Invalid or missing "${field}" in document ${documentId}.`,
    );
  }

  return value.trim();
}

function requiredDate(
  data: DocumentData,
  field: string,
  documentId: string,
): Date {
  const value = data[field];

  if (!(value instanceof Timestamp)) {
    throw new Error(
      `Invalid or missing "${field}" in document ${documentId}.`,
    );
  }

  return value.toDate();
}

function optionalDate(
  data: DocumentData,
  field: string,
  documentId: string,
): Date | null {
  const value = data[field];

  if (value == null) {
    return null;
  }

  if (!(value instanceof Timestamp)) {
    throw new Error(
      `Invalid "${field}" in document ${documentId}.`,
    );
  }

  return value.toDate();
}

function optionalString(
  data: DocumentData,
  field: string,
): string | null {
  const value = data[field];

  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim();

  return normalized.length > 0 ? normalized : null;
}

function requiredAmount(
  data: DocumentData,
  field: string,
  documentId: string,
): number {
  const value = data[field];

  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < 0
  ) {
    throw new Error(
      `Invalid "${field}" in document ${documentId}.`,
    );
  }

  return value;
}

function isAlreadyExists(error: unknown): boolean {
  const firestoreError = error as {
    code?: number | string;
  };

  return (
    firestoreError.code === 6 ||
    firestoreError.code === "already-exists"
  );
}

// ============================================================================
// TENANCY TARGET RESOLVER
//
// Mirrors:
// lib/features/billing/domain/services/
// tenancy_billing_target_resolver.dart
//
// Historical tenancy:
//   tenancyHistories
//   status = ended
//   startedAt and endedAt are inclusive
//
// Current tenancy:
//   tenants
//   status = active
//   tenancyStartedAt is required
//
// floorId:
//   floorNumber.toString()
// ============================================================================

async function loadBillingTargets({
  ownerId,
  propertyId,
  billingPeriodStart,
  billingPeriodEnd,
}: {
  ownerId: string;
  propertyId: string;
  billingPeriodStart: Date;
  billingPeriodEnd: Date;
}): Promise<BillingTarget[]> {
  const normalizedOwnerId = ownerId.trim();
  const normalizedPropertyId = propertyId.trim();

  const periodStart = dateOnly(billingPeriodStart);
  const periodEndExclusive = dateOnly(billingPeriodEnd);
  const periodEndInclusive = addDays(periodEndExclusive, -1);

  if (normalizedOwnerId.length === 0) {
    throw new Error("Owner ID is required.");
  }

  if (normalizedPropertyId.length === 0) {
    throw new Error("Property ID is required.");
  }

  if (periodEndExclusive <= periodStart) {
    throw new Error("Invalid billing period.");
  }

  // --------------------------------------------------------------------------
  // 1. LOAD UNITS
  // --------------------------------------------------------------------------

  const unitsSnapshot = await db
    .collection(UNIT_COLLECTION)
    .where("propertyId", "==", normalizedPropertyId)
    .get();

  const floorByUnitId = new Map<string, string>();

  for (const unitDoc of unitsSnapshot.docs) {
    const data = unitDoc.data();

    if (typeof data.floorNumber !== "number") {
      logger.warn("Unit has invalid floorNumber.", {
        unitId: unitDoc.id,
      });

      continue;
    }

    floorByUnitId.set(
      unitDoc.id,
      String(data.floorNumber),
    );
  }

  const targets: BillingTarget[] = [];

  // --------------------------------------------------------------------------
  // 2. HISTORICAL ENDED TENANCIES
  //
  // Same query strategy as TenancyHistoryDataSource:
  // ownerId + unitId
  // --------------------------------------------------------------------------

  for (const [unitId, floorId] of floorByUnitId.entries()) {
    const historySnapshot = await db
      .collection(TENANCY_HISTORY_COLLECTION)
      .where("ownerId", "==", normalizedOwnerId)
      .where("unitId", "==", unitId)
      .get();

    for (const historyDoc of historySnapshot.docs) {
      const data = historyDoc.data();

      if (data.status !== "ended") {
        continue;
      }

      if (data.propertyId !== normalizedPropertyId) {
        continue;
      }

      const historyUnitId = optionalString(data, "unitId");
      const tenantId = optionalString(data, "tenantId");

      if (!historyUnitId || !tenantId) {
        continue;
      }

      const startedAt = requiredDate(
        data,
        "startedAt",
        historyDoc.id,
      );

      const endedAt = requiredDate(
        data,
        "endedAt",
        historyDoc.id,
      );

      const tenancyStart = dateOnly(startedAt);
      const tenancyEnd = dateOnly(endedAt);

      if (tenancyEnd < tenancyStart) {
        logger.warn("Invalid historical tenancy date range.", {
          historyId: historyDoc.id,
        });

        continue;
      }

      const overlapStart = maxDate(
        tenancyStart,
        periodStart,
      );

      const overlapEnd = minDate(
        tenancyEnd,
        periodEndInclusive,
      );

      if (overlapStart > overlapEnd) {
        continue;
      }

      targets.push({
        floorId,
        unitId: historyUnitId,
        tenantId,
        tenantUserId: optionalString(data, "tenantUserId"),
        tenancyHistoryId: historyDoc.id,
        tenancyStart: overlapStart,
        tenancyEnd: overlapEnd,
      });
    }
  }

  // --------------------------------------------------------------------------
  // 3. CURRENT ACTIVE TENANCIES
  //
  // Same fields as Tenant entity:
  // ownerId, propertyId, unitId, status, userId,
  // tenancyStartedAt
  // --------------------------------------------------------------------------

  const tenantsSnapshot = await db
    .collection(TENANT_COLLECTION)
    .where("propertyId", "==", normalizedPropertyId)
    .get();

  for (const tenantDoc of tenantsSnapshot.docs) {
    const data = tenantDoc.data();

    if (data.status !== "active") {
      continue;
    }

    if (data.ownerId !== normalizedOwnerId) {
      continue;
    }

    if (data.propertyId !== normalizedPropertyId) {
      continue;
    }

    const unitId = optionalString(data, "unitId");

    if (!unitId) {
      continue;
    }

    const floorId = floorByUnitId.get(unitId);

    if (!floorId) {
      continue;
    }

    const startedAt = optionalDate(
      data,
      "tenancyStartedAt",
      tenantDoc.id,
    );

    if (!startedAt) {
      continue;
    }

    const tenancyStart = dateOnly(startedAt);

    const overlapStart = maxDate(
      tenancyStart,
      periodStart,
    );

    if (overlapStart > periodEndInclusive) {
      continue;
    }

    targets.push({
      floorId,
      unitId,
      tenantId: tenantDoc.id,
      tenantUserId: optionalString(data, "userId"),
      tenancyHistoryId: null,
      tenancyStart: overlapStart,
      tenancyEnd: periodEndInclusive,
    });
  }

  // --------------------------------------------------------------------------
  // 4. REMOVE EXACT DUPLICATE TARGETS
  //
  // Same key as the Dart resolver:
  // unitId + tenantId + tenancyStart + tenancyEnd
  // --------------------------------------------------------------------------

  const uniqueTargets = new Map<string, BillingTarget>();

  for (const target of targets) {
    const key = [
      target.unitId,
      target.tenantId,
      target.tenancyStart.getTime(),
      target.tenancyEnd.getTime(),
    ].join("_");

    uniqueTargets.set(key, target);
  }

  const result = [...uniqueTargets.values()];

  // Stable ordering: unit -> tenancy start -> tenant.
  result.sort((a, b) => {
    const unitComparison = a.unitId.localeCompare(b.unitId);

    if (unitComparison !== 0) {
      return unitComparison;
    }

    const startComparison =
      a.tenancyStart.getTime() - b.tenancyStart.getTime();

    if (startComparison !== 0) {
      return startComparison;
    }

    return a.tenantId.localeCompare(b.tenantId);
  });

  return result;
}

// ============================================================================
// BILLING RULES
//
// Mirrors GenerateMonthlyBills:
// - getBillingRulesForPeriod()
// - _isRuleEligibleForPeriod()
// - _resolveRulesForTarget()
// ============================================================================

function parseBillingRule(
  id: string,
  data: DocumentData,
): BillingRule {
  const scopeType = data.scopeType;
  const chargeType = data.chargeType;
  const valueType = data.valueType;

  const validScopes = [
    "property",
    "floor",
    "unit",
    "tenant",
  ];

  const validChargeTypes = [
    "water",
    "gas",
    "garbage",
    "serviceCharge",
    "electricity",
    "other",
  ];

  if (!validScopes.includes(scopeType)) {
    throw new Error(`Unknown billing scope: ${scopeType}`);
  }

  if (!validChargeTypes.includes(chargeType)) {
    throw new Error(`Unknown billing charge type: ${chargeType}`);
  }

  if (valueType !== "fixed" && valueType !== "variable") {
    throw new Error(`Unknown billing value type: ${valueType}`);
  }

  const amount = requiredAmount(data, "amount", id);

  return {
    id,
    ownerId: requiredString(data, "ownerId", id),
    propertyId: requiredString(data, "propertyId", id),
    scopeType,
    scopeId: requiredString(data, "scopeId", id),
    chargeType,
    valueType,
    amount,
    title: optionalString(data, "title"),
    effectiveFrom: requiredDate(data, "effectiveFrom", id),
    effectiveTo: optionalDate(data, "effectiveTo", id),
    isActive: data.isActive === true,
  };
}


function isRuleEligibleForPeriod({
  rule,
  billingPeriodStart,
}: {
  rule: BillingRule;
  billingPeriodStart: Date;
}): boolean {
  // Inactive rules must never generate new bills.
  if (!rule.isActive) {
    return false;
  }

  const targetMonth = monthStart(billingPeriodStart);
  const startMonth = monthStart(rule.effectiveFrom);

  // Rule cannot apply before its effective month.
  if (targetMonth < startMonth) {
    return false;
  }

  // effectiveTo is exclusive.
  if (rule.effectiveTo !== null) {
    const endMonth = monthStart(rule.effectiveTo);

    if (targetMonth >= endMonth) {
      return false;
    }
  } else if (rule.valueType === "variable") {
    // Variable rule without effectiveTo applies
    // only to its effectiveFrom month.
    return (
      targetMonth.getUTCFullYear() === startMonth.getUTCFullYear() &&
      targetMonth.getUTCMonth() === startMonth.getUTCMonth()
    );
  }

  // Fixed rules recur while their effective period is valid.
  return true;
}

async function loadBillingRules({
  ownerId,
  propertyId,
  billingPeriodStart,
}: {
  ownerId: string;
  propertyId: string;
  billingPeriodStart: Date;
}): Promise<BillingRule[]> {
  const snapshot = await db
    .collection(BILLING_RULE_COLLECTION)
    .where("ownerId", "==", ownerId)
    .where("propertyId", "==", propertyId)
    .get();

  const rules = snapshot.docs.map((doc) =>
    parseBillingRule(doc.id, doc.data()),
  );

  return rules
    .filter((rule) =>
      isRuleEligibleForPeriod({
        rule,
        billingPeriodStart,
      }),
    )
    .sort(
      (a, b) =>
        b.effectiveFrom.getTime() - a.effectiveFrom.getTime(),
    );
}

function scopePriority(
  scope: BillingRule["scopeType"],
): number {
  switch (scope) {
    case "property":
      return 1;
    case "floor":
      return 2;
    case "unit":
      return 3;
    case "tenant":
      return 4;
  }
}

function valueTypePriority(
  valueType: BillingRule["valueType"],
): number {
  return valueType === "variable" ? 2 : 1;
}

function ruleMatchesTarget(
  rule: BillingRule,
  target: BillingTarget,
): boolean {
  switch (rule.scopeType) {
    case "property":
      return true;

    case "floor":
      return rule.scopeId === target.floorId;

    case "unit":
      return rule.scopeId === target.unitId;

    case "tenant":
      return rule.scopeId === target.tenantId;
  }
}

/**
 * Same resolution order as GenerateMonthlyBills:
 *
 * 1. Scope priority:
 *    tenant > unit > floor > property
 *
 * 2. Latest effectiveFrom
 *
 * 3. Variable before Fixed when both dates match
 *
 * 4. Rule ID ascending
 *
 * Only one rule is selected per charge type and target.
 */
function resolveRulesForTarget(
  rules: BillingRule[],
  target: BillingTarget,
): BillingRule[] {
  const result: BillingRule[] = [];

  for (const chargeType of CHARGE_TYPES) {
    const matchingRules = rules
      .filter((rule) => {
        return (
          rule.chargeType === chargeType &&
          ruleMatchesTarget(rule, target)
        );
      })
      .sort((a, b) => {
        const priorityComparison =
          scopePriority(b.scopeType) -
          scopePriority(a.scopeType);

        if (priorityComparison !== 0) {
          return priorityComparison;
        }

        const effectiveComparison =
          b.effectiveFrom.getTime() -
          a.effectiveFrom.getTime();

        if (effectiveComparison !== 0) {
          return effectiveComparison;
        }

        const valueComparison =
          valueTypePriority(b.valueType) -
          valueTypePriority(a.valueType);

        if (valueComparison !== 0) {
          return valueComparison;
        }

        return a.id.localeCompare(b.id);
      });

    if (matchingRules.length > 0) {
      result.push(matchingRules[0]);
    }
  }

  return result;
}

// ============================================================================
// MONTHLY UTILITY BILL GENERATION
//
// Mirrors MonthlyBillDataSource document ID:
//
// ownerId_propertyId_unitId_tenantId_type_YYYY-MM
//
// Existing bill snapshots are never overwritten.
// ============================================================================

function monthlyBillDocumentId({
  ownerId,
  propertyId,
  unitId,
  tenantId,
  type,
  period,
}: {
  ownerId: string;
  propertyId: string;
  unitId: string;
  tenantId: string;
  type: string;
  period: string;
}): string {
  return [
    ownerId,
    propertyId,
    unitId,
    tenantId,
    type,
    period,
  ].join("_");
}

function buildBillKey(
  unitId: string,
  tenantId: string,
  type: string,
): string {
  return `${unitId.trim()}_${tenantId.trim()}_${type}`;
}

async function loadExistingMonthlyBillKeys({
  ownerId,
  propertyId,
  billingPeriodStart,
}: {
  ownerId: string;
  propertyId: string;
  billingPeriodStart: Date;
}): Promise<Set<string>> {
  const snapshot = await db
    .collection(MONTHLY_BILL_COLLECTION)
    .where("ownerId", "==", ownerId)
    .where("propertyId", "==", propertyId)
    .where(
      "billingPeriodStart",
      "==",
      Timestamp.fromDate(billingPeriodStart),
    )
    .get();

  const keys = new Set<string>();

  for (const doc of snapshot.docs) {
    const data = doc.data();

    const unitId = optionalString(data, "unitId");
    const tenantId = optionalString(data, "tenantId");
    const type = optionalString(data, "type");

    if (!unitId || !tenantId || !type) {
      continue;
    }

    keys.add(buildBillKey(unitId, tenantId, type));
  }

  return keys;
}

async function createMonthlyUtilityBills({
  ownerId,
  propertyId,
  targets,
  rules,
  billingPeriodStart,
  billingPeriodEnd,
  dueDate,
}: {
  ownerId: string;
  propertyId: string;
  targets: BillingTarget[];
  rules: BillingRule[];
  billingPeriodStart: Date;
  billingPeriodEnd: Date;
  dueDate: Date;
}): Promise<number> {
  if (targets.length === 0 || rules.length === 0) {
    return 0;
  }

  const periodKey = formatPeriod(billingPeriodStart);

  const existingBillKeys = await loadExistingMonthlyBillKeys({
    ownerId,
    propertyId,
    billingPeriodStart,
  });

  let createdCount = 0;

  for (const target of targets) {
    const applicableRules = resolveRulesForTarget(
      rules,
      target,
    );

const automaticRules = applicableRules.filter(
  (rule) => rule.valueType === "fixed",
);

   for (const rule of automaticRules) {
      const type = rule.chargeType;

      const candidateKey = buildBillKey(
        target.unitId,
        target.tenantId,
        type,
      );

      // Same duplicate protection as GenerateMonthlyBills.
      if (existingBillKeys.has(candidateKey)) {
        continue;
      }

      const documentId = monthlyBillDocumentId({
        ownerId,
        propertyId,
        unitId: target.unitId,
        tenantId: target.tenantId,
        type,
        period: periodKey,
      });

      const billRef = db
        .collection(MONTHLY_BILL_COLLECTION)
        .doc(documentId);

      const now = Timestamp.now();

      // Same field names as MonthlyBillModel.toFirestore().
      const billData = {
        ownerId,
        propertyId,
        floorId: target.floorId,
        unitId: target.unitId,
        tenantId: target.tenantId,
        tenantUserId: target.tenantUserId,
        tenancyHistoryId: target.tenancyHistoryId,
        sourceRuleId: rule.id,
        type,
        valueType: rule.valueType,
        amount: rule.amount,
        paidAmount: 0,
        billingPeriodStart: Timestamp.fromDate(
          billingPeriodStart,
        ),
        billingPeriodEnd: Timestamp.fromDate(
          billingPeriodEnd,
        ),
        dueDate: Timestamp.fromDate(dueDate),
        status: "unpaid",
        createdAt: now,
        updatedAt: now,
      };

      try {
        // create() fails if this exact document already exists.
        // It never overwrites an existing payment/bill snapshot.
        await billRef.create(billData);

        existingBillKeys.add(candidateKey);
        createdCount++;
      } catch (error) {
        if (isAlreadyExists(error)) {
          existingBillKeys.add(candidateKey);

          logger.info("Monthly bill already exists.", {
            documentId,
          });

          continue;
        }

        throw error;
      }
    }
  }

  return createdCount;
}

// ============================================================================
// RENT RATE HISTORY
//
// Mirrors RentRateDataSource:
// rentRates collection
// ownerId + unitId
// effectiveFrom / effectiveTo
//
// Rate interval: [effectiveFrom, effectiveTo)
// ============================================================================

function parseRentRate(
  id: string,
  data: DocumentData,
): RentRate {
  return {
    id,
    ownerId: requiredString(data, "ownerId", id),
    propertyId: requiredString(data, "propertyId", id),
    unitId: requiredString(data, "unitId", id),
    amount: requiredAmount(data, "amount", id),
    effectiveFrom: dateOnly(
      requiredDate(data, "effectiveFrom", id),
    ),
    effectiveTo: optionalDate(
      data,
      "effectiveTo",
      id,
    ) === null
      ? null
      : dateOnly(
          optionalDate(data, "effectiveTo", id)!,
        ),
  };
}

async function loadRentRates({
  ownerId,
  unitId,
}: {
  ownerId: string;
  unitId: string;
}): Promise<RentRate[]> {
  const snapshot = await db
    .collection(RENT_RATE_COLLECTION)
    .where("ownerId", "==", ownerId)
    .where("unitId", "==", unitId)
    .get();

  const rates = snapshot.docs.map((doc) =>
    parseRentRate(doc.id, doc.data()),
  );

  rates.sort(
    (a, b) =>
      a.effectiveFrom.getTime() - b.effectiveFrom.getTime(),
  );

  return rates;
}

function rateAppliesOn(
  rate: RentRate,
  date: Date,
): boolean {
  const normalizedDate = dateOnly(date);

  if (normalizedDate < rate.effectiveFrom) {
    return false;
  }

  if (
    rate.effectiveTo !== null &&
    normalizedDate >= rate.effectiveTo
  ) {
    return false;
  }

  return true;
}

function resolveRentRateSegments({
  rentRates,
  chargePeriodStart,
  chargePeriodEnd,
}: {
  rentRates: RentRate[];
  chargePeriodStart: Date;
  chargePeriodEnd: Date;
}): RentSegment[] {
  const start = dateOnly(chargePeriodStart);
  const end = dateOnly(chargePeriodEnd);

  if (end < start) {
    throw new Error("Invalid rent charge period.");
  }

  if (rentRates.length === 0) {
    throw new Error("No rent rate history is available.");
  }

  const segments: RentSegment[] = [];

  let cursor = start;

  while (cursor <= end) {
    const applicableRates = rentRates
      .filter((rate) => rateAppliesOn(rate, cursor))
      .sort(
        (a, b) =>
          b.effectiveFrom.getTime() -
          a.effectiveFrom.getTime(),
      );

    const selectedRate = applicableRates[0];

    if (!selectedRate) {
      throw new Error(
        `No rent rate applies on ${formatDate(cursor)}.`,
      );
    }

    const nextRateStart = rentRates
      .filter(
        (rate) =>
          rate.effectiveFrom > cursor &&
          rate.effectiveFrom <= end,
      )
      .sort(
        (a, b) =>
          a.effectiveFrom.getTime() -
          b.effectiveFrom.getTime(),
      )[0]?.effectiveFrom;

    let segmentEnd = end;

    if (selectedRate.effectiveTo !== null) {
      const dayBeforeEnd = addDays(
        selectedRate.effectiveTo,
        -1,
      );

      segmentEnd = minDate(segmentEnd, dayBeforeEnd);
    }

    if (nextRateStart !== undefined) {
      segmentEnd = minDate(
        segmentEnd,
        addDays(nextRateStart, -1),
      );
    }

    if (segmentEnd < cursor) {
      throw new Error("Invalid rent-rate segment.");
    }

    segments.push({
      rate: selectedRate,
      start: cursor,
      end: segmentEnd,
    });

    cursor = addDays(segmentEnd, 1);
  }

  // Validate continuous coverage.
  if (
    segments.length === 0 ||
    !sameCalendarDate(segments[0].start, start) ||
    !sameCalendarDate(segments[segments.length - 1].end, end)
  ) {
    throw new Error(
      "Rent-rate history does not cover the complete charge period.",
    );
  }

  for (let index = 1; index < segments.length; index++) {
    const expectedNextDate = addDays(
      segments[index - 1].end,
      1,
    );

    if (
      !sameCalendarDate(
        segments[index].start,
        expectedNextDate,
      )
    ) {
      throw new Error(
        "Rent-rate history contains a gap.",
      );
    }
  }

  return segments;
}

// ============================================================================
// EXISTING MONTHLY RENT RECORDS
//
// Mirrors MonthlyRentDataSource document ID:
//
// ownerId_unitId_tenantId_YYYY-MM_startDate_endDate
// ============================================================================

function monthlyRentDocumentId({
  ownerId,
  unitId,
  tenantId,
  period,
  chargePeriodStart,
  chargePeriodEnd,
}: {
  ownerId: string;
  unitId: string;
  tenantId: string;
  period: string;
  chargePeriodStart: Date;
  chargePeriodEnd: Date;
}): string {
  return [
    ownerId,
    unitId,
    tenantId,
    period,
    formatDate(chargePeriodStart),
    formatDate(chargePeriodEnd),
  ].join("_");
}

function buildRentKey(
  tenantId: string,
  chargePeriodStart: Date,
  chargePeriodEnd: Date,
): string {
  return [
    tenantId.trim(),
    formatDate(chargePeriodStart),
    formatDate(chargePeriodEnd),
  ].join("_");
}

async function loadExistingMonthlyRents({
  ownerId,
  unitId,
  billingPeriodStart,
}: {
  ownerId: string;
  unitId: string;
  billingPeriodStart: Date;
}): Promise<Set<string>> {
  const snapshot = await db
    .collection(MONTHLY_RENT_COLLECTION)
    .where("ownerId", "==", ownerId)
    .where("unitId", "==", unitId)
    .where(
      "billingPeriodStart",
      "==",
      Timestamp.fromDate(billingPeriodStart),
    )
    .get();

  const existing = new Set<string>();

  for (const doc of snapshot.docs) {
    const data = doc.data();

    const tenantId = optionalString(data, "tenantId");

    if (!tenantId) {
      continue;
    }

    const start = requiredDate(
      data,
      "chargePeriodStart",
      doc.id,
    );

    const end = requiredDate(
      data,
      "chargePeriodEnd",
      doc.id,
    );

    existing.add(
      buildRentKey(tenantId, start, end),
    );
  }

  return existing;
}

// ============================================================================
// MONTHLY RENT GENERATION
//
// Mirrors GenerateMonthlyRent + MonthlyRentGenerationCalculator.
//
// - Historical tenancy dates are inclusive.
// - Billing period end is exclusive.
// - Rent-rate periods are [effectiveFrom, effectiveTo).
// - Proration uses calendar days in the full billing month.
// - Each rent-rate segment creates a separate MonthlyRent.
// - Existing rent snapshots are never modified.
// ============================================================================

async function createMonthlyRentsForTarget({
  ownerId,
  propertyId,
  target,
  billingPeriodStart,
  billingPeriodEnd,
  dueDate,
}: {
  ownerId: string;
  propertyId: string;
  target: BillingTarget;
  billingPeriodStart: Date;
  billingPeriodEnd: Date;
  dueDate: Date;
}): Promise<number> {
  const rentRates = await loadRentRates({
    ownerId,
    unitId: target.unitId,
  });

  if (rentRates.length === 0) {
    logger.warn("No rent rate history found for unit.", {
      ownerId,
      propertyId,
      unitId: target.unitId,
      tenantId: target.tenantId,
    });

    return 0;
  }

  const periodStart = dateOnly(billingPeriodStart);
  const periodEndInclusive = addDays(
    dateOnly(billingPeriodEnd),
    -1,
  );

  const chargePeriodStart = maxDate(
    dateOnly(target.tenancyStart),
    periodStart,
  );

  const chargePeriodEnd = minDate(
    dateOnly(target.tenancyEnd),
    periodEndInclusive,
  );

  if (chargePeriodEnd < chargePeriodStart) {
    return 0;
  }

  const segments = resolveRentRateSegments({
    rentRates,
    chargePeriodStart,
    chargePeriodEnd,
  });

  const daysInBillingPeriod = daysBetweenInclusive(
    periodStart,
    periodEndInclusive,
  );

  const existingRentKeys = await loadExistingMonthlyRents({
    ownerId,
    unitId: target.unitId,
    billingPeriodStart: periodStart,
  });

  const periodKey = formatPeriod(periodStart);

  let createdCount = 0;

  for (const segment of segments) {
    const chargeableDays = daysBetweenInclusive(
      segment.start,
      segment.end,
    );

    if (chargeableDays <= 0) {
      continue;
    }

    const prorationFactor =
      chargeableDays / daysInBillingPeriod;

    const amount = roundCurrency(
      segment.rate.amount * prorationFactor,
    );

    if (amount <= 0) {
      continue;
    }

    const rentKey = buildRentKey(
      target.tenantId,
      segment.start,
      segment.end,
    );

    if (existingRentKeys.has(rentKey)) {
      continue;
    }

    const documentId = monthlyRentDocumentId({
      ownerId,
      unitId: target.unitId,
      tenantId: target.tenantId,
      period: periodKey,
      chargePeriodStart: segment.start,
      chargePeriodEnd: segment.end,
    });

    const rentRef = db
      .collection(MONTHLY_RENT_COLLECTION)
      .doc(documentId);

    const now = Timestamp.now();

    // Same fields as MonthlyRentModel.toFirestore().
    const rentData = {
      ownerId,
      propertyId,
      unitId: target.unitId,
      tenantId: target.tenantId,
      tenantUserId: target.tenantUserId,
      rentRateId: segment.rate.id,
      monthlyRate: segment.rate.amount,
      amount,
      paidAmount: 0,
      chargeableDays,
      daysInBillingPeriod,
      prorationFactor,
      billingPeriodStart: Timestamp.fromDate(periodStart),
      billingPeriodEnd: Timestamp.fromDate(
        dateOnly(billingPeriodEnd),
      ),
      chargePeriodStart: Timestamp.fromDate(segment.start),
      chargePeriodEnd: Timestamp.fromDate(segment.end),
      dueDate: Timestamp.fromDate(dueDate),
      status: "unpaid",
      createdAt: now,
      updatedAt: now,
    };

    try {
      await rentRef.create(rentData);

      existingRentKeys.add(rentKey);
      createdCount++;
    } catch (error) {
      if (isAlreadyExists(error)) {
        existingRentKeys.add(rentKey);

        logger.info("Monthly rent already exists.", {
          documentId,
        });

        continue;
      }

      throw error;
    }
  }

  return createdCount;
}

// ============================================================================
// PROCESS ONE PROPERTY
// ============================================================================

async function processProperty({
  ownerId,
  propertyId,
  billingPeriodStart,
  billingPeriodEnd,
  dueDate,
}: {
  ownerId: string;
  propertyId: string;
  billingPeriodStart: Date;
  billingPeriodEnd: Date;
  dueDate: Date;
}): Promise<{
  targetCount: number;
  generatedRents: number;
  generatedBills: number;
  failedRentTargets: number;
}> {
  const targets = await loadBillingTargets({
    ownerId,
    propertyId,
    billingPeriodStart,
    billingPeriodEnd,
  });

  if (targets.length === 0) {
    logger.info("No tenancy targets found for property.", {
      ownerId,
      propertyId,
      period: formatPeriod(billingPeriodStart),
    });

    return {
      targetCount: 0,
      generatedRents: 0,
      generatedBills: 0,
      failedRentTargets: 0,
    };
  }

  const rules = await loadBillingRules({
    ownerId,
    propertyId,
    billingPeriodStart,
  });

  let generatedRents = 0;
  let failedRentTargets = 0;

  // Process each target independently.
  // One failed rent target must not prevent other tenants
  // or utility bill generation.
  for (const target of targets) {
    try {
      generatedRents += await createMonthlyRentsForTarget({
        ownerId,
        propertyId,
        target,
        billingPeriodStart,
        billingPeriodEnd,
        dueDate,
      });
    } catch (error) {
      failedRentTargets++;

      logger.error("Rent generation failed for tenancy target.", {
        ownerId,
        propertyId,
        unitId: target.unitId,
        tenantId: target.tenantId,
        tenancyHistoryId: target.tenancyHistoryId,
        error,
      });
    }
  }

  // Utility bills are generated independently of rent generation.
  const generatedBills = await createMonthlyUtilityBills({
    ownerId,
    propertyId,
    targets,
    rules,
    billingPeriodStart,
    billingPeriodEnd,
    dueDate,
  });

  return {
    targetCount: targets.length,
    generatedRents,
    generatedBills,
    failedRentTargets,
  };
}

// ============================================================================
// SCHEDULED MONTHLY BILLING
//
// Runs at 00:10 on the first day of every month in Bangladesh.
//
// Example:
// November 2026:
// billingPeriodStart = 2026-11-01 00:00 Asia/Dhaka
// billingPeriodEnd   = 2026-12-01 00:00 Asia/Dhaka
// dueDate            = 2026-12-10 00:00 Asia/Dhaka
// ============================================================================

export const generateMonthlyBilling = onSchedule(
  {
    schedule: "10 0 1 * *",
    timeZone: TIME_ZONE,
    region: "asia-south1",
    timeoutSeconds: 540,
    memory: "1GiB",
    maxInstances: 1,
  },
  async () => {
    const now = new Date();

    const billingPeriodStart = monthStart(now);
    const billingPeriodEnd = nextMonthStart(
      billingPeriodStart,
    );

    const nextMonthParts = getDhakaDateParts(
      billingPeriodEnd,
    );

    const dueDate = dhakaDate(
      nextMonthParts.year,
      nextMonthParts.month,
      DUE_DAY,
    );

    const period = formatPeriod(billingPeriodStart);

    logger.info("Monthly billing scheduler started.", {
      period,
      billingPeriodStart: formatDate(billingPeriodStart),
      billingPeriodEnd: formatDate(billingPeriodEnd),
      dueDate: formatDate(dueDate),
    });

    // PropertyModel uses:
    // status: PropertyStatus.active.name
    const propertiesSnapshot = await db
      .collection(PROPERTY_COLLECTION)
      .where("status", "==", "active")
      .get();

    let processedProperties = 0;
    let failedProperties = 0;
    let totalTargets = 0;
    let totalRents = 0;
    let totalBills = 0;
    let failedRentTargets = 0;

    for (const propertyDoc of propertiesSnapshot.docs) {
      const propertyData = propertyDoc.data();

      const ownerId = optionalString(
        propertyData,
        "ownerId",
      );

      if (!ownerId) {
        logger.warn("Property has no valid ownerId.", {
          propertyId: propertyDoc.id,
        });

        failedProperties++;
        continue;
      }

      try {
        const result = await processProperty({
          ownerId,
          propertyId: propertyDoc.id,
          billingPeriodStart,
          billingPeriodEnd,
          dueDate,
        });

        processedProperties++;
        totalTargets += result.targetCount;
        totalRents += result.generatedRents;
        totalBills += result.generatedBills;
        failedRentTargets += result.failedRentTargets;

        logger.info("Property monthly billing completed.", {
          ownerId,
          propertyId: propertyDoc.id,
          period,
          ...result,
        });
      } catch (error) {
        failedProperties++;

        logger.error("Property monthly billing failed.", {
          ownerId,
          propertyId: propertyDoc.id,
          period,
          error,
        });
      }
    }

    logger.info("Monthly billing scheduler finished.", {
      period,
      totalProperties: propertiesSnapshot.size,
      processedProperties,
      failedProperties,
      totalTargets,
      totalRents,
      totalBills,
      failedRentTargets,
    });

    if (failedProperties > 0 || failedRentTargets > 0) {
      logger.error("Monthly billing completed with errors.", {
        failedProperties,
        failedRentTargets,
      });
    }
  },
);
