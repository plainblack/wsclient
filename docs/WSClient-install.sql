SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `WSClient` (
  `callMethod` text,
  `uri` varchar(255) NOT NULL default '',
  `proxy` varchar(255) NOT NULL default '',
  `preprocessMacros` int(11) NOT NULL default '0',
  `paginateAfter` int(11) NOT NULL default '50',
  `paginateVar` varchar(35) default NULL,
  `debugMode` int(11) NOT NULL default '0',
  `params` text,
  `execute_by_default` tinyint(4) NOT NULL default '1',
  `decodeUtf8` tinyint(3) unsigned NOT NULL default '0',
  `httpHeader` varchar(50) default NULL,
  `sharedCache` tinyint(3) unsigned NOT NULL default '0',
  `cacheTTL` smallint(5) unsigned NOT NULL default '60',
  `assetId` varchar(22) character set utf8 collate utf8_bin NOT NULL default '',
  `templateId` varchar(22) character set utf8 collate utf8_bin NOT NULL default '',
  `revisionDate` bigint(20) NOT NULL default '0',
  PRIMARY KEY  (`assetId`,`revisionDate`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;
