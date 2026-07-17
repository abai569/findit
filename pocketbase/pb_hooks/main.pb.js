/// <reference path="../pb_data/types.d.ts" />

routerAdd("POST", "/api/findit/create-family", (e) => {
  const body = e.requestInfo().body;
  const name = String(body.name || "").trim();
  if (!name || name.length > 100) {
    throw new BadRequestError("invalid_family_name");
  }

  let result = null;
  e.app.runInTransaction((txApp) => {
    const memberships = txApp.findRecordsByFilter(
      "family_members",
      "user = {:user}",
      "",
      1,
      0,
      { user: e.auth.id },
    );
    if (memberships.length > 0) {
      throw new BadRequestError("already_belongs_to_family");
    }

    let inviteCode = "";
    for (let i = 0; i < 10; i++) {
      const candidate = $security.randomString(8).toUpperCase();
      const existing = txApp.findRecordsByFilter(
        "families",
        "invite_code = {:code}",
        "",
        1,
        0,
        { code: candidate },
      );
      if (existing.length === 0) {
        inviteCode = candidate;
        break;
      }
    }
    if (!inviteCode) {
      throw new InternalServerError("invite_code_generation_failed");
    }

    const family = new Record(txApp.findCollectionByNameOrId("families"));
    family.set("name", name);
    family.set("invite_code", inviteCode);
    family.set("owner", e.auth.id);
    txApp.save(family);

    const member = new Record(txApp.findCollectionByNameOrId("family_members"));
    member.set("family", family.id);
    member.set("user", e.auth.id);
    member.set("role", "owner");
    txApp.save(member);

    result = {
      family_id: family.id,
      name: family.getString("name"),
      invite_code: family.getString("invite_code"),
    };
  });

  return e.json(200, result);
}, $apis.requireAuth("users"));

routerAdd("POST", "/api/findit/join-family", (e) => {
  const body = e.requestInfo().body;
  const inviteCode = String(body.invite_code || "").trim().toUpperCase();
  if (!inviteCode) {
    throw new BadRequestError("invalid_invite_code");
  }

  let result = null;
  e.app.runInTransaction((txApp) => {
    const memberships = txApp.findRecordsByFilter(
      "family_members",
      "user = {:user}",
      "",
      1,
      0,
      { user: e.auth.id },
    );
    if (memberships.length > 0) {
      throw new BadRequestError("already_belongs_to_family");
    }

    const families = txApp.findRecordsByFilter(
      "families",
      "invite_code = {:code}",
      "",
      1,
      0,
      { code: inviteCode },
    );
    if (families.length === 0) {
      throw new BadRequestError("invalid_invite_code");
    }
    const family = families[0];

    const member = new Record(txApp.findCollectionByNameOrId("family_members"));
    member.set("family", family.id);
    member.set("user", e.auth.id);
    member.set("role", "member");
    txApp.save(member);

    result = {
      family_id: family.id,
      name: family.getString("name"),
      invite_code: family.getString("invite_code"),
    };
  });

  return e.json(200, result);
}, $apis.requireAuth("users"));

onRecordCreateRequest((e) => {
  if (e.hasSuperuserAuth()) return e.next();
  const helpers = require(`${__hooks}/findit.js`);
  const familyId = e.record.getString("family");
  helpers.assertFamilyMember(e.app, e.auth && e.auth.id, familyId);
  const parentId = e.record.getString("parent");
  if (parentId) {
    const parent = e.app.findRecordById("locations", parentId);
    if (parent.getString("family") !== familyId) {
      throw new BadRequestError("parent_family_mismatch");
    }
  }
  e.next();
}, "locations");

onRecordUpdateRequest((e) => {
  if (e.hasSuperuserAuth()) return e.next();
  const helpers = require(`${__hooks}/findit.js`);
  const familyId = e.record.getString("family");
  helpers.assertFamilyMember(e.app, e.auth && e.auth.id, familyId);
  if (familyId !== e.record.original().getString("family")) {
    throw new BadRequestError("family_cannot_be_changed");
  }
  const parentId = e.record.getString("parent");
  if (parentId) {
    const parent = e.app.findRecordById("locations", parentId);
    if (parent.getString("family") !== familyId) {
      throw new BadRequestError("parent_family_mismatch");
    }
  }
  e.next();
}, "locations");

onRecordDeleteRequest((e) => {
  if (e.hasSuperuserAuth()) return e.next();
  const helpers = require(`${__hooks}/findit.js`);
  helpers.assertFamilyMember(
    e.app,
    e.auth && e.auth.id,
    e.record.getString("family"),
  );
  e.next();
}, "locations");

onRecordCreateRequest((e) => {
  if (e.hasSuperuserAuth()) return e.next();
  const helpers = require(`${__hooks}/findit.js`);
  helpers.assertFamilyMember(
    e.app,
    e.auth && e.auth.id,
    e.record.getString("family"),
  );
  e.next();
}, "categories");

onRecordUpdateRequest((e) => {
  if (e.hasSuperuserAuth()) return e.next();
  const helpers = require(`${__hooks}/findit.js`);
  helpers.assertFamilyMember(
    e.app,
    e.auth && e.auth.id,
    e.record.getString("family"),
  );
  if (e.record.getString("family") !== e.record.original().getString("family")) {
    throw new BadRequestError("family_cannot_be_changed");
  }
  e.next();
}, "categories");

onRecordDeleteRequest((e) => {
  if (e.hasSuperuserAuth()) return e.next();
  const helpers = require(`${__hooks}/findit.js`);
  helpers.assertFamilyMember(
    e.app,
    e.auth && e.auth.id,
    e.record.getString("family"),
  );
  e.next();
}, "categories");

onRecordCreateRequest((e) => {
  if (e.hasSuperuserAuth()) return e.next();
  const helpers = require(`${__hooks}/findit.js`);
  const familyId = e.record.getString("family");
  helpers.assertFamilyMember(e.app, e.auth && e.auth.id, familyId);
  const location = e.app.findRecordById("locations", e.record.getString("location"));
  if (location.getString("family") !== familyId) {
    throw new BadRequestError("location_family_mismatch");
  }
  const categoryId = e.record.getString("category");
  if (categoryId) {
    const category = e.app.findRecordById("categories", categoryId);
    if (category.getString("family") !== familyId) {
      throw new BadRequestError("category_family_mismatch");
    }
  }
  e.next();
}, "items");

onRecordUpdateRequest((e) => {
  if (e.hasSuperuserAuth()) return e.next();
  const helpers = require(`${__hooks}/findit.js`);
  const familyId = e.record.getString("family");
  helpers.assertFamilyMember(e.app, e.auth && e.auth.id, familyId);
  if (familyId !== e.record.original().getString("family")) {
    throw new BadRequestError("family_cannot_be_changed");
  }
  const location = e.app.findRecordById("locations", e.record.getString("location"));
  if (location.getString("family") !== familyId) {
    throw new BadRequestError("location_family_mismatch");
  }
  const categoryId = e.record.getString("category");
  if (categoryId) {
    const category = e.app.findRecordById("categories", categoryId);
    if (category.getString("family") !== familyId) {
      throw new BadRequestError("category_family_mismatch");
    }
  }
  e.next();
}, "items");

onRecordDeleteRequest((e) => {
  if (e.hasSuperuserAuth()) return e.next();
  const helpers = require(`${__hooks}/findit.js`);
  helpers.assertFamilyMember(
    e.app,
    e.auth && e.auth.id,
    e.record.getString("family"),
  );
  e.next();
}, "items");
