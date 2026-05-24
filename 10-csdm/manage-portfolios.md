# Manage Portfolios

**CSDM v5 domain — Manage Portfolios** *(new explicit cross-cutting domain in v5)*

A **cross-domain view** spanning Foundation, Design & Planning, Build & Integration, Service Delivery, and Service Consumption. Represents the breadth of a service owner's responsibility — financial accountability for the business application, oversight of the deployed service instances, alignment of business consumption.

This domain doesn't have many tables of its own; it's mostly a *lens* over other domains' tables.

## Manage Portfolios entities

| Entity | Table | Notes |
|---|---|---|
| Portfolio | (various) | A collection of services, products, projects, or applications grouped by objective, capability, organisation, or geography |
| Service Portfolio | `service_portfolio` | Not a CMDB CI; hierarchical classification of business and/or technical services |

## How it relates to other domains

- **Foundation** — common ownership data underpins portfolio assignment
- **Design & Planning** — Business Application portfolio is one of the things Service Owner oversees
- **Service Delivery** — Service Instances tied to the BAs owned by the Service Owner
- **Service Consumption** — Business Services and BSOs are the primary surface of the Service Owner

## Service Owner responsibility example

For an HR Service Owner:
- Financial responsibility for the **Business Application** that provides HR services (Design & Planning)
- Direct responsibility for oversight of the **Application Services / Service Instances** (Service Delivery)
- Not responsible for technical troubleshooting/repair (that's Technology Management Service & Offerings)
- Accountable for the **business impact** the application has on the business (Service Consumption)

## Key v5 relationships

| From | Relationship | To |
|---|---|---|
| Service Portfolio | uses reference | Business Service |
| Business Service | Reference (`Is part of`) | Service Portfolio |
| Technology Management Service | Reference | Service Portfolio (since Rome — TMS can reference Service Portfolio nodes) |

## Class notes

*(none yet — Service Portfolio is referenced by other classes but has not been a first-class engagement subject.)*

## Why it matters

- **CCH maturity**: Manage Portfolios is part of **Fly** maturity (Business Capability + Service Portfolio + strategic relationships). CCH is not at Fly maturity yet — Service Portfolio is a future-state concern.
- **Stakeholder mapping**: When asked "who owns this?", the Service Portfolio hierarchy is the canonical answer. Without it, ownership questions default to looking at the support_group on a Service Offering — partial, not authoritative.

## Related notes

- [README](README.md)
- [service-consumption](service-consumption.md) — where the Business Services that roll up to Service Portfolios live
