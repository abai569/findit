function assertFamilyMember(app, userId, familyId) {
  if (!userId || !familyId) {
    throw new ForbiddenError("family_membership_required");
  }
  const memberships = app.findRecordsByFilter(
    "family_members",
    "user = {:user} && family = {:family}",
    "",
    1,
    0,
    { user: userId, family: familyId },
  );
  if (memberships.length === 0) {
    throw new ForbiddenError("family_membership_required");
  }
}

module.exports = { assertFamilyMember };
