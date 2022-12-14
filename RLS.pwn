#include <a_samp>
#include <a_mysql>
#include <foreach>

#define function%0(%1)			forward%0(%1);		public%0(%1)
#define SCM  					SendClientMessage
#define MIN_PASS_LEN 			4
#define MAX_PASS_LEN 			64

enum
{
	DIALOG_REGISTER,
	DIALOG_LOGIN,
	DIALOG_EMAIL,
	DIALOG_EMAIL_PROVIDER,
	DIALOG_GENDER,
	DIALOG_AGE,
};

enum E_PlayerInfo
{
	pSQLID,
	pName[24 + 1],
	pPassword[64 + 1],
	pEmail[24 + 1],
	pEmailProvider[12 + 1],
	pGender,
	pAge,
	pSkin,
};

enum E_PlayerData
{
	pOpenDialog,
	pLoginTry,
	Cache:CacheID,
};

new PlayerInfo[MAX_PLAYERS][E_PlayerInfo],
	PlayerData[MAX_PLAYERS][E_PlayerData],
	PlayerSession[MAX_PLAYERS],
	gString[512],

	Iterator:PlayersOnline<MAX_PLAYERS>,
	MySQL: SQL;

main(){}

public OnGameModeInit()
{
	SQL = mysql_connect_file("mysql.ini");

	return 0;
}

public OnGameModeExit()
{
	foreach(new i : Player)
	{
		OnPlayerDisconnect(i, 0);
	}

	mysql_close();

	return 0;
}

public OnPlayerConnect(playerid)
{
	PlayerSession[playerid]++;

	static const Empty_PlayerInfo[E_PlayerInfo]; PlayerInfo[playerid] = Empty_PlayerInfo;
	static const Empty_PlayerData[E_PlayerData]; PlayerData[playerid] = Empty_PlayerData;

	GetPlayerName(playerid, PlayerInfo[playerid][pName], 24 + 1);
	if(IsNumeric(PlayerInfo[playerid][pName]))
		return Kick(playerid); 

	gString[0] = 0;
	mysql_format(SQL, gString, sizeof gString, "SELECT * FROM `USERS` WHERE `NAME` = '%e' LIMIT 1", PlayerInfo[playerid][pName]);
	mysql_tquery(SQL, gString, "OPCA", "ii", playerid, PlayerSession[playerid]);

	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	PlayerSession[playerid]++;

	Iter_Remove(PlayersOnline, playerid);

	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	SetSpawnInfo(playerid, PlayerInfo[playerid][pSkin], 0, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	return 1;
}

public OnPlayerRequestSpawn(playerid) return Kick(playerid);	

public OnPlayerSpawn(playerid)
{
	if(!Iter_Contains(PlayersOnline, playerid))
	{
		TogglePlayerControllable(playerid, false);
		TogglePlayerSpectating(playerid, true);
	}

	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if(PlayerData[playerid][pOpenDialog] != 1)
		return Kick(playerid);
	PlayerData[playerid][pOpenDialog] = 0;

	switch(dialogid)
	{
		case DIALOG_REGISTER:
		{
			if(!response) 
				return Kick(playerid);

			if(!IsPassOK(inputtext))
				return SPD(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register", "Baga o parola buna fmm", "Register", "Quit");
		
			SHA256_PassHash(inputtext, "17389960", PlayerInfo[playerid][pPassword], 64 + 1);

			SPD(playerid, DIALOG_EMAIL_PROVIDER, DIALOG_STYLE_LIST, "E-Mail Provider", "@GMAIL.COM\n@YAHOO.COM\n@OUTLOOK.COM\n@HOTMAIL.COM", "Select", "Quit");
		}

		case DIALOG_EMAIL_PROVIDER:
		{
			if(!response)
				return Kick(playerid);

			format(PlayerInfo[playerid][pEmailProvider], 12 + 1, inputtext);

			SPD(playerid, DIALOG_EMAIL, DIALOG_STYLE_INPUT, "E-Mail", "E-Mail:", "Add", "Quit");
		}

		case DIALOG_EMAIL:
		{
			if(!response)
				return Kick(playerid);

			if(strlen(inputtext) < 4 || strlen(inputtext) > 24)
				return SPD(playerid, DIALOG_EMAIL, DIALOG_STYLE_INPUT, "E-Mail", "Wrong E-Mail", "Add", "Quit");

			if(!SafeString(inputtext))
				return SPD(playerid, DIALOG_EMAIL, DIALOG_STYLE_INPUT, "E-Mail", "Wrong E-Mail", "Add", "Quit");

			format(PlayerInfo[playerid][pEmail], 24, "%s%s", inputtext, PlayerInfo[playerid][pEmailProvider]);

			SPD(playerid, DIALOG_GENDER, DIALOG_STYLE_MSGBOX, "Gender", "Gender:", "Male", "Female");
		}

		case DIALOG_GENDER:
		{
			if(!response)
				PlayerInfo[playerid][pGender] = 0;

			PlayerInfo[playerid][pGender] = 1;

			SPD(playerid, DIALOG_AGE, DIALOG_STYLE_INPUT, "Age", "Age:", "Add", "Quit");
		}

		case DIALOG_AGE:
		{
			if(!response)
				return Kick(playerid);

			if(!IsNumeric(inputtext))
				return SPD(playerid, DIALOG_AGE, DIALOG_STYLE_INPUT, "Age", "Wrong Age:", "Add", "Quit");

			if(strval(inputtext) < 6 || strval(inputtext) > 100)
				return SPD(playerid, DIALOG_AGE, DIALOG_STYLE_INPUT, "Age", "Wrong Age:", "Add", "Quit");

			PlayerInfo[playerid][pAge] = strval(inputtext);

			gString[0] = 0;
			mysql_format(SQL, gString, sizeof gString, "INSERT INTO `USERS` (`NAME`, `PASSWORD`, `EMAIL`, `GENDER`, `AGE`) VALUES('%e', '%e', '%e', '%d', '%d')", PlayerInfo[playerid][pName], PlayerInfo[playerid][pPassword], PlayerInfo[playerid][pEmail], PlayerInfo[playerid][pGender], PlayerInfo[playerid][pAge], PlayerInfo[playerid][pSkin] = 250);
			mysql_tquery(SQL, gString, "OPIA", "i", playerid);
		}

		case DIALOG_LOGIN:
		{
			if(!response)
				return Kick(playerid);

			if(4 < strlen(inputtext) > 64)
				return SPD(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Wrong Pass.", "Login", "Quit");

			if(!SafeString(inputtext))
				return SPD(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Wrong Pass.", "Login", "Quit");
		
			new TEMPPASS[64 + 1];
			SHA256_PassHash(inputtext, "17389960", TEMPPASS, sizeof TEMPPASS);
			if(!strcmp(TEMPPASS, PlayerInfo[playerid][pPassword], false, 64 + 1))
			{
				cache_set_active(PlayerData[playerid][CacheID]);

				if(PlayerInfo[playerid][pSQLID] == 0)
				{
					cache_get_value_int(0, "ID", PlayerInfo[playerid][pSQLID]);
					cache_get_value_int(0, "GENDER", PlayerInfo[playerid][pGender]);
					cache_get_value_int(0, "AGE", PlayerInfo[playerid][pAge]);

					cache_get_value(0, "EMAIL", PlayerInfo[playerid][pEmail]);
					cache_get_value_int(0, "SKIN", PlayerInfo[playerid][pSkin]);
				}

				cache_delete(PlayerData[playerid][CacheID]);

				TogglePlayerControllable(playerid, true);
				TogglePlayerSpectating(playerid, false);

				Iter_Add(PlayersOnline, playerid);
				SpawnPlayer(playerid);
				SetPlayerSkin(playerid, PlayerInfo[playerid][pSkin]);

			//format(gString, sizeof gString, "SKIN %d", PlayerInfo[playerid][pEmal]);
				SCM(playerid, -1, PlayerInfo[playerid][pEmail]);
			}
			else
			{
				if(PlayerData[playerid][pLoginTry] == 3)
					return Kick(playerid);
				PlayerData[playerid][pLoginTry]++;
			
				SPD(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Login", "Login", "Quit");
			}
			
		}	
	}

	return 1;
}

function OPCA(playerid, session)
{
	if(session != PlayerSession[playerid])
		return Kick(playerid);

	if(!cache_num_rows())
		return SPD(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register", "Register Pass.", "Register", "Quit");

	cache_get_value(0, "PASSWORD", PlayerInfo[playerid][pPassword], 64 + 1);

	SPD(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Login Pass.", "Login", "Quit");

	return 1;
}

function OPIA(playerid)
{	
	PlayerInfo[playerid][pSQLID] = cache_insert_id();

	SPD(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Login:", "Login", "Quit");

	return 1;
}

function SPD(playerid, dialogid, style, caption[], info[], button1[], button2[])
{
	ShowPlayerDialog(playerid, dialogid, style, caption, info, button1, button2);
	PlayerData[playerid][pOpenDialog] = 1;

	return 1;
}

stock SafeString(const string[])
{
	for(new i, j = strlen(string); i < j; i++)
	{
		if(string[i] < 32 || string[i] > 127 || string[i] == '\\' || string[i] == '\'' || string[i] == '\"' || string[i] == '@') return 0;
	}

	return 1;
}

stock IsNumeric(const string[])
{
	if(!SafeString(string)) return 0;

	for(new i, j = strlen(string); i < j; i++)
	{
		if(string[i] < '0' || string[i] > '9') return 0;
	}

	return 1;
}

stock IsPassOK(const string[])
{
    new len = strlen(string);
 
    if(len < MIN_PASS_LEN || len > MAX_PASS_LEN) return 0;
 
    new hasDigit, hasUpperLetter, hasLowerLetter;
 
    for(new i; i < len; i++)
    {
        if((string[i] >= '0' && string[i] <= '9') && hasDigit == 0) hasDigit = 1;
        if((string[i] >= 'A' && string[i] <= 'Z') && hasUpperLetter == 0) hasUpperLetter = 1;
        if((string[i] >= 'a' && string[i] <= 'z') && hasLowerLetter == 0) hasLowerLetter = 1;
    }
 
    if((hasDigit + hasUpperLetter + hasLowerLetter) == 3) return 1;
 
    return 0;
}