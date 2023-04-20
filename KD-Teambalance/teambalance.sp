#include <sourcemod>
#include <cstrike>

public Plugin myinfo =
{
	name = "Team Balance (K/D based)",
	author = "TwójNick",
	description = "Utrzymuje równowagę drużyn na serwerze CS:GO na podstawie K/D graczy",
	version = "1.0",
	url = ""
};

// Ustawienia domyślne
float g_fBalanceThreshold = 0.5;

public void OnPluginStart()
{
	LoadConfig();
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
}

public void LoadConfig()
{
	char configPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/team_balance.cfg");

	KeyValues kv = new KeyValues("TeamBalanceSettings");
	if (kv.LoadFromFile(configPath) == false)
	{
		LogError("Nie można załadować pliku konfiguracyjnego: %s", configPath);
		return;
	}

	g_fBalanceThreshold = kv.GetNum("balance_threshold", 0.5);
	kv.Close();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	int lowestKDClient = -1;
	float lowestKD = 99999.0;
	int teamToSwitch = -1;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || GetClientTeam(i) == CS_TEAM_SPECTATOR)
			continue;

		int kills = CS_GetClientKills(i);
		int deaths = CS_GetClientDeaths(i);
		float kdr = (deaths > 0) ? float(kills) / float(deaths) : 0.0;

		if (kdr < lowestKD)
		{
			lowestKD = kdr;
			lowestKDClient = i;
			teamToSwitch = GetClientTeam(i) == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T;
		}
	}
	if (lowestKDClient != -1 && IsValidClient(lowestKDClient))
	{
		if (teamToSwitch == CS_TEAM_T)
		{
			if (AverageKDR(CS_TEAM_CT) - AverageKDR(CS_TEAM_T) > g_fBalanceThreshold)
			{
				ChangeClientTeam(lowestKDClient, CS_TEAM_T);
				FreezeClient(lowestKDClient, true);
				ReplyToCommand(lowestKDClient, "Zostałeś przeniesiony do drużyny T, aby utrzymać równowagę drużyn.");
			}
		}
		else if (teamToSwitch == CS_TEAM_CT)
		{
			if (AverageKDR(CS_TEAM_T) - AverageKDR(CS_TEAM_CT) > g_fBalanceThreshold)
			{
				ChangeClientTeam(lowestKDClient, CS_TEAM_CT);
				FreezeClient(lowestKDClient, true);
				ReplyToCommand(lowestKDClient, "Zostałeś przeniesiony do drużyny CT, aby utrzymać równowagę drużyn.");
			}
		}
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			FreezeClient(i, false);
		}
	}
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && !IsClientSourceTV(client) && !IsClientReplay(client);
}

void FreezeClient(int client, bool freeze)
{
	if (freeze)
	{
		SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_FROZEN);
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);
	}
}

float AverageKDR(int team)
{
	int teamSize = 0;
	float teamKDRSum = 0.0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == team)
		{
			teamSize++;
			int kills = CS_GetClientKills(i);
			int deaths = CS_GetClientDeaths(i);
			float kdr = (deaths > 0) ? float(kills) / float(deaths) : 0.0;
			teamKDRSum += kdr;
		}
	}

	return (teamSize > 0) ? teamKDRSum / float(teamSize) : 0.0;
}
