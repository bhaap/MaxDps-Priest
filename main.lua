--- @type MaxDps
if not MaxDps then
	return ;
end

local MaxDps = MaxDps;

local Priest = MaxDps:NewModule('Priest');

local SH = {
	Shadowform         = 232698,
	MindBlast          = 8092,
	--ShadowWordVoid     = 205351,
	ShadowWordPain     = 589,
	VampiricTouch      = 34914,
	Misery             = 238558,
	VoidEruption       = 228260,
	--DarkAscension      = 280711,
	--Voidform           = 228264,
	Voidform           = 194249,
	VoidBolt           = 228266,
	VoidBolt2          = 205448,
	--DarkVoid           = 263346,
	SurrenderToMadness = 193223,
	Mindbender         = 200174,
	Shadowfiend        = 34433,
	ShadowCrash        = 205385,
	MindSear           = 48045,
	ShadowWordDeath    = 32379,
	VoidTorrent        = 263165,
	--LegacyOfTheVoid    = 193225,
	MindFlay           = 15407,
	SearingNightmare   = 341385,
	Damnation          = 341374,
	DevouringPlague.   = 335467
};

-- Spells
local DI = {
	Penance            = 47540,
	PurgeTheWicked     = 204197,
	ShadowWordDeath    = 32379,
	PurgeTheWickedAura = 204213,
	Penance            = 47540,
	Smite              = 585,
	SmiteAura          = 208772,
	PowerWordSolace    = 129250,
	ShadowWordPain     = 589,
	Schism             = 214621,
	DivineStar         = 110744,
	Shadowfiend        = 34433,
	Mindbender         = 123040
};

local spellMeta = {
	__index = function(t, k)
		print('Spell Key ' .. k .. ' not found!');
	end
}

setmetatable(SH, spellMeta);

function Priest:Enable()
	MaxDps:Print(MaxDps.Colors.Info .. 'Priest [Shadow, Discipline]');

	if MaxDps.Spec == 1 then
		MaxDps.NextSpell = Priest.Discipline;
	elseif MaxDps.Spec == 2 then
		MaxDps.NextSpell = Priest.Holy;
	elseif MaxDps.Spec == 3 then
		MaxDps.NextSpell = Priest.Shadow;
	end ;

	return true;
end

function Priest:Discipline()
	local fd = MaxDps.FrameData;
	local debuff = fd.debuff;
	local talents = fd.talents;
	local currentSpell = fd.currentSpell;
	local buff = fd.buff;
	local cooldown = fd.cooldown;

	MaxDps:GlowEssences();

	if talents[DI.Mindbender] then
		MaxDps:GlowCooldown(DI.Mindbender, cooldown[DI.Mindbender].ready);
	else
		MaxDps:GlowCooldown(DI.Shadowfiend, cooldown[DI.Shadowfiend].ready);
	end

	if talents[DI.PurgeTheWicked] then
		if debuff[DI.PurgeTheWickedAura].refreshable then
			return DI.PurgeTheWicked;
		end
	else
		if debuff[DI.ShadowWordPain].refreshable then
			return DI.ShadowWordPain;
		end
	end

	if talents[DI.Schism] and cooldown[DI.Schism].ready and currentSpell ~= DI.Schism then
		return DI.Schism;
	end

	if talents[DI.PowerWordSolace] and cooldown[DI.PowerWordSolace].ready then
		return DI.PowerWordSolace;
	end

	if cooldown[DI.Penance].ready then
		return DI.Penance;
	end

	return DI.Smite;
end

function Priest:Holy()
	return nil;
end

function Priest:Shadow()
	local fd = MaxDps.FrameData;
	local debuff = fd.debuff;
	local talents = fd.talents;
	local buff = fd.buff;
	local cooldown = fd.cooldown;
	local targets = MaxDps:SmartAoe();
	fd.targets = targets;
	fd.targetHp = MaxDps:TargetPercentHealth();

	local VoidBolt = MaxDps:FindSpell(SH.VoidEruption) and SH.VoidEruption or
		(MaxDps:FindSpell(SH.VoidBolt) and SH.VoidBolt or SH.VoidBolt2);
	fd.VoidBolt = VoidBolt;

	MaxDps:GlowEssences();

	if talents[SH.SurrenderToMadness] then
		MaxDps:GlowCooldown(
			SH.SurrenderToMadness,
			cooldown[SH.SurrenderToMadness].ready and buff[SH.Voidform].count >= 15
		);
	end

	if not talents[SH.Mindbender] then
		MaxDps:GlowCooldown(SH.Shadowfiend, cooldown[SH.Shadowfiend].ready);
	end

	if not InCombatLockdown() then
		return Priest:ShadowPrecombat();
	end

	-- run_action_list,name=aoe,if=spell_targets.mind_sear>(5+1*talent.misery.enabled);
	if targets > (5 + (talents[SH.Misery] and 1 or 0)) then
		return Priest:ShadowAoe();
	end

	-- run_action_list,name=cleave,if=active_enemies>1;
	if targets > 1 then
		return Priest:ShadowCleave();
	end

	-- run_action_list,name=single,if=active_enemies=1;
	return Priest:ShadowSingle();
end

function Priest:ShadowPrecombat()
	local fd = MaxDps.FrameData;
	local buff = fd.buff;
	local currentSpell = fd.currentSpell;
	local cooldown = fd.cooldown;
	local talents = fd.talents;

	-- shadowform,if=!buff.shadowform.up;
	if not buff[SH.Shadowform].up and not buff[SH.Voidform].up then
		return SH.Shadowform;
	end

	-- mind_blast;
	if cooldown[SH.MindBlast].ready and currentSpell ~= SH.MindBlast then
		return SH.MindBlast;
	end
end

function Priest:ShadowAoe()
	local fd = MaxDps.FrameData;
	local cooldown = fd.cooldown;
	local buff = fd.buff;
	local debuff = fd.debuff;
	local currentSpell = fd.currentSpell;
	local talents = fd.talents;
	local gcd = fd.gcd;
	local insanity = UnitPower('player', Enum.PowerType.Insanity);
	local VoidBolt = fd.VoidBolt;

	-- void_eruption;
	if not buff[SH.Voidform].up and cooldown[SH.VoidEruption].ready then
		return SH.VoidEruption;
	end

	-- void_bolt,if=talent.dark_void.enabled&dot.shadow_word_pain.remains>travel_time;
	if buff[SH.Voidform].up and cooldown[SH.VoidBolt2].remains < gcd and debuff[SH.ShadowWordPain].remains > gcd * 2 then
		return VoidBolt;
	end

	-- mindbender;
	if talents[SH.Mindbender] and cooldown[SH.Mindbender].ready then
		return SH.Mindbender;
	end

	-- shadow_crash,if=raid_event.adds.in>5&raid_event.adds.duration<20;
	if talents[SH.ShadowCrash] and cooldown[SH.ShadowCrash].ready then
		return SH.ShadowCrash;
	end
	
	if talents[SH.SearingNightmare] and currentspell = SH.MindSear and insanity => 35 then
		return SH.SearingNightmare;
	end
	
	if not talents[SH.SearingNightmare] and insanity => 50 then
		return SH.DevouringPlague;
	end
	
	-- mind_sear,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(cooldown.void_bolt.up|cooldown.mind_blast.up);
	return SH.MindSear;
end

function Priest:ShadowCleave()
	local fd = MaxDps.FrameData;
	local cooldown = fd.cooldown;
	local buff = fd.buff;
	local debuff = fd.debuff;
	local currentSpell = fd.currentSpell;
	local talents = fd.talents;
	local targets = fd.targets;
	local gcd = fd.gcd;
	local timeToDie = fd.timeToDie;
	local targetHp = fd.targetHp;
	local VoidBolt = fd.VoidBolt;
	local insanity = UnitPower('player', Enum.PowerType.Insanity);

	-- void_eruption;
	if not buff[SH.Voidform].up and currentSpell ~= SH.VoidEruption then
		return SH.VoidEruption;
	end

	-- void_bolt;
	if buff[SH.Voidform].up and cooldown[SH.VoidBolt2].remains < gcd then
		return VoidBolt;
	end

	-- shadow_word_death,target_if=target.time_to_die<3|buff.voidform.down;
	if cooldown[SH.ShadowWordDeath] and targetHp < 0.2 then
		return SH.ShadowWordDeath;
	end

	-- mindbender;
	if talents[SH.Mindbender] and cooldown[SH.Mindbender].ready then
		return SH.Mindbender;
	end

	-- mind_blast;
	if cooldown[SH.MindBlast].ready and currentSpell ~= SH.MindBlast then
		return SH.MindBlast;
	end
	
	if not talents[SH.SearingNightmare] and insanity => 50 then
		return SH.DevouringPlague;
	end
	
	if talents[SH.SearingNightmare] and currentspell = SH.MindSear and insanity => 35 then
		return SH.SearingNightmare;
	end
	
	-- shadow_crash,if=(raid_event.adds.in>5&raid_event.adds.duration<2)|raid_event.adds.duration>2;
	if talents[SH.ShadowCrash] and cooldown[SH.ShadowCrash].ready and targets >= 2 then
		return SH.ShadowCrash;
	end

	-- shadow_word_pain,target_if=refreshable&target.time_to_die>4,if=!talent.misery.enabled&!talent.dark_void.enabled;
	if debuff[SH.ShadowWordPain].refreshable and timeToDie > 4 and
		not talents[SH.Misery]
	then
		return SH.ShadowWordPain;
	end
	
	if debuff[SH.ShadowWordPain].refreshable and timeToDie > 4 and
		talents[SH.Misery]
	then
		return SH.VampiricTouch;
	end

	-- vampiric_touch,target_if=refreshable,if=(target.time_to_die>6);
	if debuff[SH.VampiricTouch].refreshable and currentSpell ~= SH.VampiricTouch and timeToDie > 6 then
		return SH.VampiricTouch;
	end

	-- void_torrent,if=buff.voidform.up;
	if talents[SH.VoidTorrent] and cooldown[SH.VoidTorrent].ready and debuff[SH.DevouringPlague].refreshable then
		return SH.VoidTorrent;
	end

	-- mind_sear,target_if=spell_targets.mind_sear>2,chain=1,interrupt=1;
	if targets > 2 then
		return SH.MindSear;
	end

	-- mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(cooldown.void_bolt.up|cooldown.mind_blast.up);
	return SH.MindFlay;
end

function Priest:ShadowSingle()
	local fd = MaxDps.FrameData;
	local cooldown = fd.cooldown;
	local buff = fd.buff;
	local debuff = fd.debuff;
	local currentSpell = fd.currentSpell;
	local talents = fd.talents;
	local timeToDie = fd.timeToDie;
	local targets = fd.targets;
	local targetHp = fd.targetHp;
	local VoidBolt = fd.VoidBolt;
	local gcd = fd.gcd;
	local insanity = UnitPower('player', Enum.PowerType.Insanity);

	-- variable,name=dots_up,op=set,value=dot.shadow_word_pain.ticking&dot.vampiric_touch.ticking;
	local dotsUp = debuff[SH.ShadowWordPain].up and debuff[SH.VampiricTouch].up;

	-- void_eruption;
	if not buff[SH.Voidform].up and currentSpell ~= SH.VoidEruption then
		return SH.VoidEruption;
	end

	-- void_bolt;
	if buff[SH.Voidform].up and cooldown[SH.VoidBolt2].remains < gcd then
		return VoidBolt;
	end

	-- mindbender;
	if talents[SH.Mindbender] and cooldown[SH.Mindbender].ready and buff[SH.Voidform].up then
		return SH.Mindbender;
	end
	
	if insanity => 50 then
		return SH.DevouringPlague;
	end
	
	-- shadow_crash,if=raid_event.adds.in>5&raid_event.adds.duration<20;
	if talents[SH.ShadowCrash] and cooldown[SH.ShadowCrash].ready then
		return SH.ShadowCrash;
	end

	-- mind_blast,if=variable.dots_up;
	if cooldown[SH.MindBlast].ready and currentSpell ~= SH.MindBlast and dotsUp then
		return SH.MindBlast;
	end

	-- shadow_word_pain,if=refreshable&target.time_to_die>4&!talent.misery.enabled&!talent.dark_void.enabled;
	if debuff[SH.ShadowWordPain].refreshable and timeToDie > 4 and not talents[SH.Misery] then
		return SH.ShadowWordPain;
	end

	-- vampiric_touch,if=refreshable&target.time_to_die>6|(talent.misery.enabled&dot.shadow_word_pain.refreshable);
	if currentSpell ~= SH.VampiricTouch and (
		debuff[SH.VampiricTouch].refreshable and timeToDie > 6 or
		(talents[SH.Misery] and debuff[SH.ShadowWordPain].refreshable)
	) then
		return SH.VampiricTouch;
	end
	
	if talents[SH.VoidTorrent] and cooldown[SH.VoidTorrent].ready and debuff[SH.DevouringPlague].refreshable then
		return SH.VoidTorrent;
	end

	-- mind_flay,chain=1,interrupt_immediate=1,interrupt_if=ticks>=2&(cooldown.void_bolt.up|cooldown.mind_blast.up);
	return SH.MindFlay;
end

