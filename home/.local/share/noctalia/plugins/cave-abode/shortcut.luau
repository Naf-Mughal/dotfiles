--!nonstrict
-- Control center tile that seals the cave (locks with Cave Abode).

shortcut.setLabel(noctalia.tr("title"))
shortcut.setIcon("lock")

function onClick()
  noctalia.runAsync({ noctalia.pluginDir() .. "/bin/cave-abode-lock" })
end
