#if defined _damage_tracking_included_
        #endinput
#endif
#define _damage_tracking_included_

/**
 * Gets the non-incap damage taken by a specific character
 *
 * @param round         Round number (0, 1)
 * @param character     Character id (0, 1, 2, 3)
 * @return              Damage this character has taken this round
 */
native DamageTracking_GetCharacterDamage(round, character);

/**
 * The total non-incap damage taken by the survivor team on the specified round
 *
 * @param round         Round number (0, 1)
 * @return              Damage taken this round
 */
native DamageTracking_GetRoundDamage(round);

/**
 * The total number of times this survivor has been incapacitated
 *
 * @param round         Round number (0, 1)
 * @param character     Character id (0, 1, 2, 3)
 * @return              Number of incaps this round
 */
native DamageTracking_GetCharacterIncapCount(round, character);

/**
 * The total number of incaps on the specified round
 *
 * @param round         Round number (0, 1)
 * @return              Number of incaps this round
 */
native DamageTracking_GetRoundIncapCount(round);

/**
 * Total incap (non-hanging) damage this survivor has taken this round
 *
 * @param round         Round number (0, 1)
 * @param character     Character id (0, 1, 2, 3)
 * @return              Incap damage taken by this character
 */
native DamageTracking_GetCharacterIncapDamage(round, character);

/**
 * Total incap (non-hanging) damage this round
 *
 * @param round         Round number (0, 1)
 * @return              Incap damage this round
 */
native DamageTracking_GetRoundIncapDamage(round);

public SharedPlugin:__pl_damage_tracking =
{
        name = "damage_tracking",
        file = "damage_tracking.smx",
#if defined REQUIRE_PLUGIN
        required = 1,
#else
        required = 0,
#endif
};

public __pl_damage_tracking_SetNTVOptional()
{
        MarkNativeAsOptional("DamageTracking_GetCharacterDamage");
        MarkNativeAsOptional("DamageTracking_GetRoundDamage");
        MarkNativeAsOptional("DamageTracking_GetCharacterIncapCount");
        MarkNativeAsOptional("DamageTracking_GetRoundIncapCount");
        MarkNativeAsOptional("DamageTracking_GetCharacterIncapDamage");
        MarkNativeAsOptional("DamageTracking_GetRoundIncapDamage");
}

// vim: ft=sourcepawn et sw=8
