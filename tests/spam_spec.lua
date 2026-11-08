local helper = require("tests.helper")

describe("Spam.isRecruitment", function()
  local Spam

  before_each(function()
    Spam = helper.loadPure({ "Modules/Shields/Spam.lua" }).Spam
  end)

  it("catches English recruitment", function()
    assert.is_true(Spam.isRecruitment("<Nightfall> is RECRUITING for Mythic raid!"))
    assert.is_true(Spam.isRecruitment("Chill guild looking for members, join our discord"))
    assert.is_true(Spam.isRecruitment("Guild LF more raiders, apply now"))
  end)

  it("catches German recruitment", function()
    assert.is_true(Spam.isRecruitment("Gilde sucht Mitglieder für M+ und Raid"))
    assert.is_true(Spam.isRecruitment("Wir rekrutieren! Verstärkung gesucht"))
    assert.is_true(Spam.isRecruitment("<Sturmwind> Gilde sucht Verstärkung"))
  end)

  it("leaves normal chat alone", function()
    assert.is_false(Spam.isRecruitment("WTS flasks, cheap"))
    assert.is_false(Spam.isRecruitment("LFM +10 key, need healer"))
    assert.is_false(Spam.isRecruitment("Does anyone know where the guild bank is?"))
    assert.is_false(Spam.isRecruitment("Wo ist der Gildenmeister?"))
  end)

  it("handles missing text", function()
    assert.is_false(Spam.isRecruitment(nil))
  end)
end)
