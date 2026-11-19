export interface QuickCustomerInput {
  first_name: string;
  last_name: string;
  phone: string;
  email?: string;
  company_name?: string;
  metadata?: Record<string, unknown>;
}

export interface POSCustomerRecord {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  company_name?: string;
  has_account: boolean;
  metadata: Record<string, unknown>;
  created_at: string;
}

// In-memory registered customers repository for Medusa POS plugin
export const posCustomerStore: POSCustomerRecord[] = [
  {
    id: "cus_01JOHN_DOE",
    first_name: "John",
    last_name: "Doe",
    email: "john.doe@example.com",
    phone: "+254712345678",
    company_name: "Nairobi Tech Ltd",
    has_account: true,
    metadata: {
      company_name: "Nairobi Tech Ltd",
      is_pos_registered: true,
      registered_via: "seed",
    },
    created_at: "2026-01-10T08:00:00.000Z",
  },
  {
    id: "cus_02JANE_SMITH",
    first_name: "Jane",
    last_name: "Smith",
    email: "jane.smith@urbandevicecare.co.uk",
    phone: "+254722998877",
    company_name: "Urban Studios",
    has_account: true,
    metadata: {
      company_name: "Urban Studios",
      is_pos_registered: true,
      registered_via: "seed",
    },
    created_at: "2026-02-15T09:30:00.000Z",
  },
];

/**
 * Creates a registered Medusa v2 customer with required fields and auto-generated walk-in email fallback.
 */
export async function createQuickCustomerWorkflow(
  input: QuickCustomerInput
): Promise<POSCustomerRecord> {
  const firstName = (input.first_name || "").trim();
  const lastName = (input.last_name || "").trim();
  const phone = (input.phone || "").trim();

  if (!firstName) {
    throw new Error("First name is required for customer registration");
  }
  if (!lastName) {
    throw new Error("Last name is required for customer registration");
  }
  if (!phone) {
    throw new Error("Phone number is required for customer registration");
  }

  const cleanPhone = phone.replace(/[^a-zA-Z0-9]/g, "").toLowerCase();
  if (!cleanPhone) {
    throw new Error("Phone number must contain at least one valid digit or character");
  }

  // Validate email format if provided
  let email = (input.email || "").trim().toLowerCase();
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error("Invalid email format. Leave blank to auto-generate a valid walk-in fallback email.");
  }

  // Medusa v2 registered customer unique email constraint:
  // If email is omitted, generate walkin_{phone}@pos.urbandevicecare.co.uk fallback
  if (!email) {
    const baseEmail = `walkin_${cleanPhone}@pos.urbandevicecare.co.uk`;
    email = baseEmail;

    // Check if baseEmail already exists for the same customer (idempotency)
    const existing = posCustomerStore.find((c) => c.email.toLowerCase() === baseEmail);
    if (existing) {
      const isSamePerson =
        existing.first_name.toLowerCase() === firstName.toLowerCase() &&
        existing.last_name.toLowerCase() === lastName.toLowerCase();
      if (isSamePerson) {
        return existing;
      }
      // Different customer sharing the same phone - ensure Medusa v2 unique email constraint
      let counter = 2;
      while (posCustomerStore.some((c) => c.email.toLowerCase() === `walkin_${cleanPhone}_${counter}@pos.urbandevicecare.co.uk`)) {
        counter++;
      }
      email = `walkin_${cleanPhone}_${counter}@pos.urbandevicecare.co.uk`;
    }
  } else {
    // Explicit email: prevent duplicate registered email if already exists
    const existingByEmail = posCustomerStore.find(
      (c) => c.email.toLowerCase() === email
    );
    if (existingByEmail) {
      return existingByEmail;
    }
  }

  const companyName = (input.company_name || "").trim() || undefined;
  const customerId = `cus_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

  const newCustomer: POSCustomerRecord = {
    id: customerId,
    first_name: firstName,
    last_name: lastName,
    email,
    phone,
    company_name: companyName,
    has_account: true, // Registered client, not guest
    metadata: {
      ...(input.metadata || {}),
      company_name: companyName,
      is_pos_registered: true,
      registered_via: "pos_quick_customer",
      created_at: new Date().toISOString(),
    },
    created_at: new Date().toISOString(),
  };

  posCustomerStore.unshift(newCustomer);
  return newCustomer;
}

/**
 * Searches registered POS customers by name, phone, email, or company name.
 */
export async function searchCustomersWorkflow(
  query: string
): Promise<POSCustomerRecord[]> {
  const q = (query || "").trim().toLowerCase();
  if (!q) {
    return [...posCustomerStore];
  }

  return posCustomerStore.filter((c) => {
    const fullName = `${c.first_name} ${c.last_name}`.toLowerCase();
    const phone = (c.phone || "").toLowerCase();
    const email = (c.email || "").toLowerCase();
    const company = (c.company_name || "").toLowerCase();

    return (
      fullName.includes(q) ||
      phone.includes(q) ||
      email.includes(q) ||
      company.includes(q)
    );
  });
}
