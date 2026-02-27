# Firestore User Features Optimization Plan (CutLine)

## Goals
- Keep reads under the free tier (50k/day) while supporting ~1k users.
- Remove global scans and long-lived listeners that read unnecessary data.
- Prefer summary documents and denormalized fields for user-facing UI.
- Cache stable data locally with TTL and refresh only when needed.

## Read Budget (rough target)
- Target per user per day: ~40-50 reads.
- Users open the app infrequently; owners/barbers open it frequently.
- For user features, prefer cached data and summary docs.

## Data Classification + Cache Policy
- Static (TTL 24h): salon profile, services, barbers list, gallery photos, platform fee.
- Semi-static (TTL 5-15 min): salons_summary (isOpen, avgWaitMinutes, topServices).
- Realtime (no long cache): active queue, booking status updates (listen only on active screens).

## Schema Updates (User Features)
- salons_summary/{salonId}
  - Add fields: waitingCount, servingCount, avgWaitMinutes, topServices, coverImageUrl, updatedAt.
- salons/{salonId}/queue
  - Add: customerAvatar, barberAvatar, barberId, dateKey, slotKey (optional).
- salons/{salonId}/bookings
  - Add: barberId, barberAvatar, customerAvatar, dateKey, slotKey, updatedAt.
- users/{uid}/bookings/{bookingId}
  - Mirror minimal booking data for My Booking screen:
    salonId, salonName, coverImageUrl, services, barberName, dateTime, status, updatedAt.
  - Write on booking create/cancel (client or Cloud Function).

## Screen-by-Screen Plan (User Features)

### 1) Waiting List
File: lib/features/user/providers/waiting_list_provider.dart
- Remove collectionGroup fallback (no global queue/bookings reads).
- Require salonId; if missing, show empty state.
- Query only active statuses, add limit (e.g., 50) and optional orderBy(dateTime).
- Use customerAvatar from queue/bookings (no user doc fetch).

### 2) My Bookings
File: lib/features/user/providers/my_booking_provider.dart
- Replace collectionGroup queries with users/{uid}/bookings subcollection.
- If fallback needed, limit by date range (e.g., last 90 days) and use indexes.
- Store coverImageUrl in booking mirror to avoid extra salon doc reads.

### 3) Salon Details
File: lib/features/user/providers/salon_details_provider.dart
- Load salons_summary first; show wait from summary (avoid queue scan).
- Load queue only when user opens Queue section (not on initial load).
- Limit queue to active items only; no full fallback get().
- Use denormalized avatars (no extra users reads).

### 4) Booking (time slots)
File: lib/features/user/providers/booking_provider.dart
- Query by date + barberId (or slotKey) and filter status server-side.
- Cache booked slots per (salonId + barberId + date) in memory for session.
- Do not scan whole bookings collection.

### 5) Booking Summary
File: lib/features/user/providers/booking_summary_provider.dart
- Use slotKey or (date + time + barberId) unique constraint.
- Consider a transaction or security rule to prevent double booking.
- Cache platform_fee locally with TTL (24h).

### 6) Salon Services
File: lib/features/user/providers/salon_services_provider.dart
- Use salonId only; avoid name-based lookup.
- Cache services list and combos (TTL 24h).
- Prefer embedded services in summary if available.

### 7) User Home + Favorites
Files: lib/features/user/providers/user_home_provider.dart
       lib/features/user/providers/favorite_salon_provider.dart
- Keep salons_summary pagination; cache pages locally (TTL 10-15 min).
- For favorites, use whereIn in chunks instead of per-doc reads if list grows.

### 8) Notifications
File: lib/features/user/providers/notification_provider.dart
- Listen only when Notifications screen is visible; dispose cancels stream.
- Keep limit 50 (already present).

## Indexes to Add
- salons/{salonId}/bookings: (date ==, barberId ==, status in) if used.
- salons/{salonId}/bookings: (status in) + orderBy(dateTime) for active queue.
- salons/{salonId}/queue: (status in) + orderBy(dateTime) if ordering.
- users/{uid}/bookings: orderBy(dateTime), optional status filter.
- salons (optional): (name ==, verificationStatus ==) only if still used.

## Implementation Phases

Phase 1 (Quick wins)
- Remove collectionGroup fallbacks (WaitingList + MyBookings).
- Add limits, drop full collection fallbacks.
- Stop loading queue on SalonDetails initial load.

Phase 2 (Schema + Denormalize)
- Add summary fields to salons_summary.
- Add avatars + barberId + slotKey to queue/booking docs.
- Add users/{uid}/bookings mirror.

Phase 3 (Cache + TTL)
- Add local cache layer for static/semi-static data.
- Use updatedAt to refresh only when needed.

Phase 4 (Measure + Tune)
- Log reads per screen session.
- Compare before/after in Firebase console.

## Acceptance Criteria
- No global collectionGroup reads for user features.
- Each user session: <= 10-15 reads for home + details + booking.
- My Bookings loads from user subcollection only.
- Queue + bookings reads limited to active items only.

## TODO Checklist
- [ ] Update WaitingListProvider to require salonId and remove collectionGroup.
- [ ] Add users/{uid}/bookings mirror on booking create/cancel.
- [ ] Add summary fields to salons_summary.
- [ ] Denormalize avatars in booking/queue docs.
- [ ] Add required indexes.
- [ ] Add TTL cache for services/barbers/photos/platform_fee.
- [ ] Backfill existing users/{uid}/bookings mirror (one-time).
