local obj = {}
obj.__index = obj

-- Metadata
obj.name = "gitlab"
obj.version = "1.0"
obj.author = "Pavel Makhov"
obj.homepage = "https://github.com/fork-my-spoons/gitlab.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.indicator = nil
obj.timer = nil
obj.gitlab_host = nil
obj.path = 'state=opened&scope=all&reviewer_username=pmakhov360'
obj.token = nil
obj.toReview = {}
obj.assignedToYou = {}

obj.iconPath = hs.spoons.resourcePath("icons")

local comment_icon = hs.styledtext.new(' ', { font = {name = 'feather', size = 12 }, color = {hex = '#4C566A'}})
local user_icon = hs.styledtext.new(' ', { font = {name = 'feather', size = 12 }, color = {hex = '#4C566A'}})
local calendar_icon = hs.styledtext.new(' ', { font = {name = 'feather', size = 12 }, color = {hex = '#4C566A'}})


local function styledText(text)
    return hs.styledtext.new(text, {color = {hex = '#4C566A'}})
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


local function updateMenu()
    local gitlab_url = obj.gitlab_host .. '/api/v4/merge_requests?' .. hs.http.convertHtmlEntities(obj.path)
    local auth_header = {}
    auth_header['PRIVATE-TOKEN'] = obj.token
    local current_time = os.time(os.date("!*t"))

    hs.http.asyncGet(gitlab_url, auth_header, function(status, body) 
        obj.toReview = {}
        local merge_requests = hs.json.decode(body)
        local to_review = #merge_requests
    
        for _, merge_request in ipairs(merge_requests) do
            hs.http.asyncGet(obj.gitlab_host .. '/api/v4/projects/' .. merge_request.project_id .. '/merge_requests/' .. merge_request.iid ..'/approval_state', auth_header, function(code, body) 
                local approvals = hs.json.decode(body)
                menu_item = { 
                    created = parse_date(merge_request.created_at),
                    title = hs.styledtext.new(merge_request.title .. '\n') 
                            .. calendar_icon .. styledText(to_time_ago(os.difftime(current_time, parse_date(merge_request.created_at))) .. '   ')
                            .. comment_icon .. styledText(tostring(merge_request.user_notes_count) .. '   ')
                            .. user_icon .. styledText(merge_request.author.name),
                    image = hs.image.imageFromURL(merge_request.author.avatar_url):setSize({w=32,h=32}),
                    checked = #approvals.rules[1].approved_by >= approvals.rules[1].approvals_required,
                    fn = function() os.execute('open ' .. merge_request.web_url) end
                }
                table.insert(obj.toReview, menu_item)
            end)
        end

        hs.http.asyncGet(obj.gitlab_host .. '/api/v4/merge_requests?state=opened', auth_header, function(status, body)
            obj.assignedToYou = {}
            local merge_requests = hs.json.decode(body)
            obj.indicator:setTitle(#merge_requests + to_review)
        
            for _, merge_request in ipairs(merge_requests) do
                hs.http.asyncGet(obj.gitlab_host .. '/api/v4/projects/' .. merge_request.project_id .. '/merge_requests/' .. merge_request.iid ..'/approval_state', auth_header, function(code, body) 
                    local approvals = hs.json.decode(body)
                    local menu_item = {
                        created = parse_date(merge_request.created_at),
                        title = hs.styledtext.new(merge_request.title .. '\n') 
                            .. calendar_icon .. styledText(to_time_ago(os.difftime(current_time, parse_date(merge_request.created_at))) .. '   ')
                            .. comment_icon .. styledText(tostring(merge_request.user_notes_count) .. '   ')
                            .. user_icon .. styledText(merge_request.author.name),
                        image = hs.image.imageFromURL(merge_request.author.avatar_url):setSize({w=32,h=32}),
                        checked = #approvals.rules[1].approved_by >= approvals.rules[1].approvals_required,
                        fn = function() os.execute('open ' .. merge_request.web_url) end
                    }
                
                    table.insert(obj.assignedToYou, menu_item)
                end)
            end
        end)

    end)
end

function obj:buildMenu()
    gitlab_menu = {}

    table.insert(gitlab_menu, { title = 'Review requests for you', disabled = true })

    table.sort(obj.toReview, function(left, right) return left.created > right.created end)
    for _,v in ipairs(obj.toReview) do 
        table.insert(gitlab_menu, v)
    end

    table.insert(gitlab_menu, { title = '-'})
    table.insert(gitlab_menu, { title = 'Assigned to you', disabled = true })
    
    table.sort(obj.assignedToYou, function(left, right) return left.created > right.created end)
    for _,v in ipairs(obj.assignedToYou) do 
        table.insert(gitlab_menu, v)
    end
    
    table.insert(gitlab_menu, { title = '-'})
    table.insert(gitlab_menu, { title = 'Refresh', fn = function() updateMenu() end})

    return gitlab_menu
end

function obj:init()
    self.indicator = hs.menubar.new()
    self.indicator:setIcon(hs.image.imageFromPath(obj.iconPath .. '/gitlab-icon-rgb.png'):setSize({w=16,h=16}), false)
    self.timer = hs.timer.new(600, updateMenu)
    obj.indicator:setMenu(self.buildMenu)

end

function obj:setup(args)
    self.gitlab_host = args.gitlab_host
    self.token = args.token
end

function obj:start()
    print('started')
    self.timer:fire()
    self.timer:start()
end


return obj