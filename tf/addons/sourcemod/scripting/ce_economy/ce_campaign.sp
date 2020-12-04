#pragma semicolon 1
#pragma newdecls required

#include <ce_util>
#include <ce_core>
#include <ce_events>
#include <ce_campaign>
#include <ce_coordinator>

#define CAMPAIGN_PROGRESS_INTERVAL 10.0

ArrayList m_hCampaigns;

char m_sCampaignEventList[128][MAX_HOOKS][128];

public Plugin myinfo =
{
	name = "Creators.TF Economy - Campaign Manager",
	author = "Creators.TF Team",
	description = "Creators.TF Campaign Manager",
	version = "1.00",
	url = "https://creators.tf"
}

ConVar ce_campaign_force_activate;

public void OnPluginStart()
{
	ce_campaign_force_activate = CreateConVar("ce_campaign_force_activate", "", "Force activates a campaign, ignores the time limit.", FCVAR_PROTECTED);
	HookConVarChange(ce_campaign_force_activate, ce_campaign_force_activate__CHANGED);
}

public void OnAllPluginsLoaded()
{
	ParseCampaignList();
}

public void ce_campaign_force_activate__CHANGED(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ParseCampaignList();
}

public void ParseCampaignList()
{
	if (UTIL_IsValidHandle(m_hCampaigns))delete m_hCampaigns;
	FlushCampaignEventsLists();

	KeyValues hConf = CE_GetEconomyConfig();
	if (!UTIL_IsValidHandle(hConf))return;

	if(hConf.JumpToKey("Contracker/Campaigns/0", false))
	{
		do {
			char sTime[128], sTitle[64], sCvarValue[64];
			hConf.GetString("title", sTitle, sizeof(sTitle));
			ce_campaign_force_activate.GetString(sCvarValue, sizeof(sCvarValue));

			if(!StrEqual(sTitle, sCvarValue))
			{
				hConf.GetString("start_time", sTime, sizeof(sTime));
				int iStartTime = TimeFromString("YYYY-MM-DD hh:mm:ss", sTime);

				hConf.GetString("end_time", sTime, sizeof(sTime));
				int iEndTime = TimeFromString("YYYY-MM-DD hh:mm:ss", sTime);

				if (!(GetTime() > iStartTime && GetTime() < iEndTime))continue;
			}
			AddCampaignToTrackList(hConf);

		} while (hConf.GotoNextKey());
	}
	delete hConf;
}

public void AddCampaignToTrackList(KeyValues hConf)
{
	if(!UTIL_IsValidHandle(m_hCampaigns))
	{
		m_hCampaigns = new ArrayList(sizeof(CECampaign));
	}

	CECampaign hCampaign;
	hConf.GetString("name", hCampaign.m_sName, 64);
	hConf.GetString("title", hCampaign.m_sTitle, 64);

	char sTime[64];
	hConf.GetString("start_time", sTime, sizeof(sTime));
	hCampaign.m_iStartTime = TimeFromString("YYYY-MM-DD hh:mm:ss", sTime);

	hConf.GetString("end_time", sTime, sizeof(sTime));
	hCampaign.m_iEndTime = TimeFromString("YYYY-MM-DD hh:mm:ss", sTime);
	
	int iIndex = m_hCampaigns.Length;

	for (int j = 0; j < MAX_HOOKS; j++)
	{
		char sKey[32];
		Format(sKey, sizeof(sKey), "hooks/%d/event", j);

		char sEvent[32];
		hConf.GetString(sKey, sEvent, sizeof(sEvent));
		if (StrEqual(sEvent, ""))continue;

		strcopy(m_sCampaignEventList[iIndex][j], sizeof(m_sCampaignEventList[][]), sEvent);
	}

	m_hCampaigns.PushArray(hCampaign);
}

public void FlushCampaignTrackList()
{
	if (!UTIL_IsValidHandle(m_hCampaigns))return;
	for (int i = 0; i < m_hCampaigns.Length; i++)
	{
		CECampaign hCampaign;
		m_hCampaigns.GetArray(i, hCampaign);

		m_hCampaigns.Erase(i);
		i--;
	}
	
	FlushCampaignEventsLists();
}

public void FlushCampaignEventsLists()
{
	for (int i = 0; i < sizeof(m_sCampaignEventList); i++)
	{
		for (int j = 0; j < sizeof(m_sCampaignEventList[]); j++)
		{
			strcopy(m_sCampaignEventList[i][j], sizeof(m_sCampaignEventList[][]), "");
		}
	}
}

public void CEEvents_OnSendEvent(int client, const char[] event, int add)
{
	if (!UTIL_IsValidHandle(m_hCampaigns))return;

	for (int i = 0; i < m_hCampaigns.Length; i++)
	{
		CECampaign hCampaign;
		m_hCampaigns.GetArray(i, hCampaign);

		for (int j = 0; j < MAX_HOOKS; j++)
		{
			if (StrEqual(m_sCampaignEventList[i][j], ""))continue;
			if (!StrEqual(m_sCampaignEventList[i][j], event))continue;

			char sMessage[125];
			Format(sMessage, sizeof(sMessage), "campaign_increment:campaign=%s,delta=%d,client=%d", hCampaign.m_sTitle, add, client);

			CESC_SendMessage(sMessage);

			break;
		}
	}
}
