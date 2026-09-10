/// How close (in logical pixels) to the bottom of a paginated list the user
/// must scroll before the next page is requested. Shared by every
/// offset-paginated list in the app (purchases, redemptions, redeem
/// offers) so "load more" kicks in at the same point everywhere instead of
/// each screen picking its own literal.
const double kLoadMoreThreshold = 200;
