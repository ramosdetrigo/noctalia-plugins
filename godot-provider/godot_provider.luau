local HOME = noctalia.getenv("HOME") or ""
local tinsert = table.insert
local sformat = string.format

local projectsCache
local maxResults: number = noctalia.getConfig("max_results") or 100
local projectsPath: string = noctalia.getConfig("projects_path") or noctalia.expandPath("~/.local/share/godot/projects.cfg")
local dataDir = noctalia.pluginDataDir()

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
  local c = 0
  for project_path in file_string:gmatch("%[([^%]]+)%]") do
    c += 1
    if c > maxResults then break end

    local project_name: string = projectName(project_path)
    tinsert(projects, {
      id = project_path,
      title = project_name,
      subtitle = project_path:gsub(HOME, "~"),
      icon = "godot",
    })
  end

  return projects
end

function filterProjects(query, projects)
  local result = {}
  for i = 1, #projects do
    local project = projects[i]

    -- score from title or id
    local project_score: number?

    if query == "" then
      project_score = getUsage(project.id)
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
 			subtitle = noctalia.tr("loading-subtitle"),
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

function getUsage(id: string)
  if id == "" then
		return 0
	end

	if dataDir then
	  local file_path = dataDir .. "/usage.json"
		local file = noctalia.readFile(file_path)
		if file then
	    return noctalia.json.decode(file)[id] or 0
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
	  local file_path = dataDir .. "/usage.json"
		local file = noctalia.readFile(file_path)

		local data = {}
		if file then
	    data = noctalia.json.decode(file)
		end

		data[id] = data[id] and data[id] + 1 or 1

		local json_str = noctalia.json.encode(data)
		noctalia.writeFile(file_path, json_str)
	end

	noctalia.runAsync(sformat("nohup godot -e %s &>/dev/null &", shellQuote(id.."/project.godot")))
end
