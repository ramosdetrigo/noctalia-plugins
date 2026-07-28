local HOME = noctalia.getenv("HOME") or ""
local tinsert = table.insert
local tremove = table.remove
local tfind = table.find
local tsort = table.sort
local sformat = string.format

local projectsCache
local projectsPath: string = noctalia.getConfig("projects_path") or noctalia.expandPath("~/.local/share/godot/projects.cfg")
local godot_command: string = noctalia.getConfig("godot_command") or "godot"
local sort_by: string = noctalia.getConfig("sort_by") or "history"
local dataDir = noctalia.pluginDataDir()

if godot_command == "" then godot_command = "godot" end

local function shellQuote(s: string)
	return "'" .. s:gsub("'", "'\"'\"'") .. "'"
end

local function trim(s: string)
	return s:match("^%s*(.-)%s*$")
end

-- Gets the project name in project.godot - fallbacks to the folder name
local function projectName(path: string)
  local p_godot: string = noctalia.readFile(path .. "/project.godot") or ""
  local project_name = p_godot:match('config/name="(.-)"%s*\n')

	return project_name and project_name:gsub("\\(.)", "%1") or path:match("([^/]+)$") or path
end

-- Get table with projects
local function getProjects(file_string: string, query: string)
  local projects = {}

  -- Gets the projects inside the projects.cfg (They're wrapped in "[]")
  for project_path in file_string:gmatch("%[([^%]]+)%]") do

    local project_name: string = projectName(project_path)
    tinsert(projects, {
      id = project_path,
      title = project_name,
      subtitle = project_path:gsub(HOME, "~"),
      icon = "godot",
    })
  end

  -- sort alphabetically
  tsort(projects, function(a, b) return a.title < b.title end)

  return projects
end

function filterProjects(query, projects)
  local result = {}
  for i = 1, #projects do
    local project = projects[i]

    -- score from title or id
    local project_score: number?

    if query == "" then
      project_score = getScore(project.id)
    else
      project_score = noctalia.fuzzyScore(query, project.title) or noctalia.fuzzyScore(query, project.id)
    end

    if query == "" or project_score ~= nil then
      project.score = project_score -- this will be overriden every time so no problem
      tinsert(result, project)
    end
  end

  return result
end

function showResults(query, projects)
  if #projects > 0 then
    launcher.setResults(query, projects)
    return
  end

 	launcher.setResults(query, {
		{
 			id = "",
 			title = noctalia.tr("no-projects-found"),
 			subtitle = noctalia.tr("no-projects-subtitle"),
 			glyph = "loader",
		},
 	})
end

function onQuery(query: string)
  query = trim(query)

	if query == "" then
	  projectsCache = nil
	end

	if projectsCache then
    launcher.setResults(query, filterProjects(query, projectsCache))
	  return
	end

	local file = noctalia.readFile(projectsPath)

	if file then
	  local all_projects = getProjects(file, query)
    showResults(query, filterProjects(query, all_projects))
	else
 	  showResults(query, {})
	end
end

function getScore(id: string)
  if id == "" then
		return 0
	end


	if dataDir then
	  if sort_by == "history" then
			local file_path = dataDir .. "/history.json"
  		local file = noctalia.readFile(file_path)
      local data = {}
  		if file then
        data = noctalia.json.decode(file)
        local i = tfind(data, id) or #data + 1
        local score = #data - i
  	    return score
  		end
		else
  	  local file_path = dataDir .. "/usage.json"
  		local file = noctalia.readFile(file_path)
  		if file then
  	    return noctalia.json.decode(file)[id] or 0
  		end
		end
	end

	return 0
end

-- Open godot editor on the selected project
function onActivate(id: string)
	if id == "" then
		return
	end

	if dataDir then
	  local file
    local file_path = dataDir .. (sort_by == "history" and "/history.json" or "/usage.json")
		file = noctalia.readFile(file_path)

		if sort_by == "history" then
  		local data = {}
  		if file then data = noctalia.json.decode(file) end

		  local i = tfind(data, id)
			if i then
	      tremove(data, i)
				tinsert(data, 1, id)
			else
			  tinsert(data, 1, id)
			end

			local json_str = noctalia.json.encode(data)
			noctalia.writeFile(file_path, json_str)
		else
		  local data = {}
  		if file then data = noctalia.json.decode(file) end
		  data[id] = data[id] and data[id] + 1 or 1
			local json_str = noctalia.json.encode(data)
			noctalia.writeFile(file_path, json_str)
		end
	end

	noctalia.runAsync(sformat("nohup %s -e %s &>/dev/null &", shellQuote(godot_command), shellQuote(id.."/project.godot")))
end
