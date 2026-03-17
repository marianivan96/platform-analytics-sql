# Platform Analytics SQL

A library of production SQL queries used to analyse user behaviour across a multi-ecosystem platform — covering the full funnel from acquisition through to retention, plus content performance, search behaviour, and growth flags.

All queries are written in MySQL and built around a real platform with 8 ecosystems and 29,000+ users.

---

## What's covered

**Acquisition**
- Signups per ecosystem with verified vs unverified breakdown
- Month-over-month growth comparison (same period last year)
- Stakeholder group breakdown — who is actually signing up

**Visitor Conversion**
- Visitor to user conversion rate per ecosystem
- High-intent visitors who never signed up (5+ pageviews, 2+ days) — missed conversions
- Anonymous vs signed-in browsing behaviour comparison

**Activation**
- Users who signed up but never took any action
- First action taken after signup — what users do first
- Average time from signup to first action (in minutes)
- 7-day activation rate per ecosystem

**Engagement**
- All action types ranked by volume and unique users
- Daily active users per ecosystem
- Repeat engagement rate — users active on 2+ days

**Retention**
- D1 / D7 / D30 cohort retention per ecosystem
- Users inactive for 2+ years by stakeholder group

**Content**
- Resources created vs published per ecosystem (publish rate)
- YTD entity counts vs same period last year (users, events, resources, initiatives, orgs)

**Search Behaviour**
- Search volume and zero-result rate per ecosystem
- Most searched queries — what users are actually looking for
- Queries that always return zero results — content gaps
- Users repeatedly searching the same zero-result query — frustration signals

**Notifications**
- Notification volume and reach per ecosystem and type

**Growth Flags**
- Ecosystems with low verification or low 7-day activation — health check
- Content categories with high demand but low supply — opportunity finder

---

## Stack

MySQL · Multi-ecosystem platform · User behaviour tracking

---

## Usage

All queries are parameterised by date range — just swap the `BETWEEN` dates to run for any period:

```sql
AND DATE(u.created_at) BETWEEN '2026-01-01' AND '2026-01-31'
```

Queries are standalone and can be run independently. No dependencies between them.
