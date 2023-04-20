#include <sourcemod>
#include <sdktools>

ArrayList teamT = new ArrayList();
ArrayList teamCT = new ArrayList();

Dictionary lastSwitched = new Dictionary();
int currentRound = 1;

public void OnPluginStart()
{
	RegConsoleCmd("sm_teambalance", Command_TeamBalance, "Balance teams based on K/D ratio");
}

public void OnClientPutInServer(int client)
{
	UpdatePlayerTeam(client);
}

public void OnClientDisconnect(int client)
{
	teamT.Remove(client);
	teamCT.Remove(client);
	lastSwitched.Delete(client);
}

public Action Command_TeamBalance(int client, int args)
{
	// Update player teams before performing balance check
	UpdateAllPlayerTeams();

	ArrayList playersToSwitch = OptimizePlayerSwitch(teamT, teamCT);

	if (playersToSwitch.Length == 0)
	{
		PrintToChat(client, "Teams are already balanced.");
		return Plugin_Handled;
	}

	int playerT = playersToSwitch.Get(0);
	int playerCT = playersToSwitch.Get(1);

	ChangeClientTeam(playerT, "CT");
	ChangeClientTeam(playerCT, "T");

	PrintToChatAll("Teams have been balanced. %s and %s have been switched.", GetClientName(playerT), GetClientName(playerCT));

	return Plugin_Handled;
}
public void UpdatePlayerTeam(int client)
{
	char team[32];
	GetClientTeam(client, team, sizeof(team));

	if (StrEqual(team, "T") || StrEqual(team, "CT"))
	{
		// Remove player from both lists to avoid duplicates
		teamT.Remove(client);
		teamCT.Remove(client);

		if (StrEqual(team, "T"))
		{
			teamT.Push(client);
		}
		else
		{
			teamCT.Push(client);
		}
	}
}

public void UpdateAllPlayerTeams()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			UpdatePlayerTeam(client);
		}
	}
}

public float AverageKDR(ArrayList team)
{
	float totalKDR = 0.0;

	for (int i = 0; i < team.Length; i++)
	{
		int client = team.Get(i);
		int kills = GetClientStat(client, "kills");
		int deaths = GetClientStat(client, "deaths");

		totalKDR += (float)kills / max(deaths, 1);
	}

	return totalKDR / team.Length;
}

public int GetClientStat(int client, const char[] stat)
{
	char command[32];
	Format(command, sizeof(command), "sm_stats_get_%s", stat);

	return RunCommand(client, command);
}

public void ChangeClientTeam(int client, const char[] team)
{
	char command[32];
	Format(command, sizeof(command), "sm_changename %s", team);

	RunCommand(client, command);
}

public int RunCommand(int client, const char[] command)
{
	FakeClientCommand(client, command);
	return GetCmdReply();
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	// Update player teams before performing balance check
	UpdateAllPlayerTeams();

	ArrayList playersToSwitch = OptimizePlayerSwitch(teamT, teamCT);

	if (playersToSwitch.Length != 0)
	{
		int playerT = playersToSwitch.Get(0);
		int playerCT = playersToSwitch.Get(1);

		ChangeClientTeam(playerT, "CT");
		ChangeClientTeam(playerCT, "T");

		lastSwitched.SetValue(playerT, currentRound);
		lastSwitched.SetValue(playerCT, currentRound);

		// Make sure switched players cannot be killed or kill others until next round
		SDKHooks_AddClientImmunity(client, AdminId:0, immunityflags:0);
		SDKHooks_AddClientImmunity(client, AdminId:0, immunityflags:0);
	}
	currentRound++;
	return Plugin_Continue;
}