local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Gitlb Merge Requests"
obj.version = "1.1"
obj.author = "Pavel Makhov"
obj.homepage = "https://github.com/fork-my-spoons/gitlab-merge-requests.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.indicator = nil
obj.timer = nil
obj.gitlab_host = nil
obj.token = nil
obj.username = nil
obj.toReview = {}
obj.assignedToYou = {}
obj.mrUrl = '%s/api/v4/merge_requests?state=opened&scope=all&%s'
obj.approvalsUrl = '%s/api/v4/projects/%s/merge_requests/%s/approval_state'

obj.iconPath = hs.spoons.resourcePath("icons")

local comment_icon = hs.styledtext.new(' ', { font = {name = 'feather', size = 12 }, color = {hex = '#8e8e8e'}})
local user_icon = hs.styledtext.new(' ', { font = {name = 'feather', size = 12 }, color = {hex = '#8e8e8e'}})
local calendar_icon = hs.styledtext.new(' ', { font = {name = 'feather', size = 12 }, color = {hex = '#8e8e8e'}})
local warning_icon = hs.styledtext.new(' ', { font = {name = 'feather', size = 12 }, color = {hex = '#ffd60a'}})
local checkbox_icon = hs.styledtext.new(' ', { font = {name = 'feather', size = 12 }, color = {hex = '#8e8e8e'}})
local checkbox_icon_green = hs.styledtext.new(' ', { font = {name = 'feather', size = 12 }, color = {hex = '#7CB342'}})
local project_icon = hs.styledtext.new(' ', { font = {name = 'feather', size = 12 }, color = {hex = '#8e8e8e'}})

local function subtitle(text)
    return hs.styledtext.new(text, {color = {hex = '#8e8e8e'}})
end

--- Converts string representation of date (2020-06-02T11:25:27Z) to date
local function parse_date(date_str)
    local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)%Z"
    local y, m, d, h, min, sec, _ = date_str:match(pattern)

    return os.time{year = y, month = m, day = d, hour = h, min = min, sec = sec}
end

--- Converts seconds to "time ago" represenation, like '1 hour ago'
local function to_time_ago(seconds)
    local days = seconds / 86400
    if days > 1 then
        days = math.floor(days + 0.5)
        return days .. (days == 1 and ' day' or ' days') .. ' ago'
    end

    local hours = (seconds % 86400) / 3600
    if hours > 1 then
        hours = math.floor(hours + 0.5)
        return hours .. (hours == 1 and ' hour' or ' hours') .. ' ago'
    end

    local minutes = ((seconds % 86400) % 3600) / 60
    if minutes > 1 then
        minutes = math.floor(minutes + 0.5)
        return minutes .. (minutes == 1 and ' minute' or ' minutes') .. ' ago'
    end
end

function obj:check_for_updates()
    local release_url = 'https://api.github.com/repos/fork-my-spoons/gitlab-merge-requests.spoon/releases/latest'
    hs.http.asyncGet(release_url, {}, function(status, body)
        local latest_release = hs.json.decode(body)
        latest = latest_release.tag_name:sub(2)
        
        if latest == obj.version then
            hs.notify.new(function() end, {
                autoWithdraw = false,
                title = 'Gitlab Merge Requests Spoon',
                informativeText = "You have the latest version installed!"
            }):send()
        else
            hs.notify.new(function() 
                os.execute('open ' .. latest_release.assets[1].browser_download_url)
            end, 
            {
                title = 'Gitlab Merge Requests Spoon',
                informativeText = "New version is available",
                actionButtonTitle = "Download",
                hasActionButton = true
            }):send()
        end
    end)
end

local function build_menu_item(merge_request, approvals, current_time)
    local isApprovedByMe = false

    for _, approver in ipairs(approvals.rules[1].approved_by) do
        if approver.username == obj.username then
            isApprovedByMe = true
        end
    end
    
    local _,_,project = string.find(merge_request.references.full, "/([%w-]+)!")

    local title = hs.styledtext.new(merge_request.title .. '\n') 
            .. project_icon .. subtitle(project .. '   ') .. user_icon .. subtitle(merge_request.author.name .. '\n')
            .. comment_icon .. subtitle(tostring(merge_request.user_notes_count) .. '   ')
            .. (isApprovedByMe and checkbox_icon_green or checkbox_icon) .. subtitle(#approvals.rules[1].approved_by .. '/' .. approvals.rules[1].approvals_required .. '   ')
            .. calendar_icon .. subtitle(to_time_ago(os.difftime(current_time, parse_date(merge_request.created_at))))

    if merge_request.merge_status == 'cannot_be_merged' then
        title = warning_icon .. title
    end

    return { 
        created = parse_date(merge_request.created_at),
        title = title,
        image = hs.image.imageFromURL(merge_request.author.avatar_url):setSize({w=36,h=36}),
        checked = #approvals.rules[1].approved_by >= approvals.rules[1].approvals_required,
        fn = function() os.execute('open ' .. merge_request.web_url) end
    }
end

local function updateMenu()
    local toReviewUrl = string.format(obj.mrUrl, obj.gitlab_host, 'reviewer_username=' .. hs.http.convertHtmlEntities(obj.username))
    local auth_header = {}
    auth_header['PRIVATE-TOKEN'] = obj.token
    local current_time = os.time(os.date("!*t"))

    hs.http.asyncGet(toReviewUrl, auth_header, function(status, body) 
        obj.toReview = {}
        local merge_requests = hs.json.decode(body)
        local to_review = #merge_requests
    
        for _, merge_request in ipairs(merge_requests) do
            hs.http.asyncGet(string.format(obj.approvalsUrl, obj.gitlab_host, merge_request.project_id, merge_request.iid), auth_header, function(code, body) 
                local approvals = hs.json.decode(body)
                local menu_item = build_menu_item(merge_request, approvals, current_time)
               
                table.insert(obj.toReview, menu_item)
            end)
        end

        local assignedToMeUrl = string.format(obj.mrUrl, obj.gitlab_host, 'assignee_username=' .. hs.http.convertHtmlEntities(obj.username))
        hs.http.asyncGet(assignedToMeUrl, auth_header, function(status, body)
            obj.assignedToYou = {}
            local merge_requests = hs.json.decode(body)
            obj.indicator:setTitle(#merge_requests + to_review)
        
            for _, merge_request in ipairs(merge_requests) do
                hs.http.asyncGet(string.format(obj.approvalsUrl, obj.gitlab_host, merge_request.project_id, merge_request.iid), auth_header, function(code, body) 
                    local approvals = hs.json.decode(body)
                    local menu_item = build_menu_item(merge_request, approvals, current_time)
                
                    table.insert(obj.assignedToYou, menu_item)
                end)
            end
        end)

    end)
end

function obj:buildMenu()
    gitlab_menu = {}

    if #obj.toReview > 0 then
        table.insert(gitlab_menu, { title = 'Review requests for you', disabled = true })

        table.sort(obj.toReview, function(left, right) return left.created > right.created end)
        for _,v in ipairs(obj.toReview) do 
            table.insert(gitlab_menu, v)
        end

        table.insert(gitlab_menu, { title = '-'})
    end

    if #obj.assignedToYou > 0 then
        table.insert(gitlab_menu, { title = 'Assigned to you', disabled = true })
        
        table.sort(obj.assignedToYou, function(left, right) return left.created > right.created end)
        for _,v in ipairs(obj.assignedToYou) do 
            table.insert(gitlab_menu, v)
        end
        
        table.insert(gitlab_menu, { title = '-'})
    end

    table.insert(gitlab_menu, { 
        image = hs.image.imageFromName('NSRefreshTemplate'), 
        title = 'Refresh', fn = function() updateMenu() end
    })

    table.insert(gitlab_menu, { 
        image = hs.image.imageFromName('NSTouchBarDownloadTemplate'), 
        title = 'Check for updates', 
        fn = function() obj:check_for_updates() end})

    return gitlab_menu
end


function obj:init()
    self.indicator = hs.menubar.new()
    self.indicator:setIcon(hs.image.imageFromPath(obj.iconPath .. '/gitlab-icon-rgb.png'):setSize({w=16,h=16}), true)
    self.timer = hs.timer.new(600, updateMenu)
    obj.indicator:setMenu(self.buildMenu)

end

function obj:setup(args)
    self.gitlab_host = args.gitlab_host
    self.token = args.token
    self.username = args.username
end

function obj:start()
    self.timer:fire()
    self.timer:start()
end


return obj