#!/usr/local/bin/ruby

require 'pstore'
require 'open-uri'
require 'rexml/document'
require 'htree'

PATH = '/home/niha28/cronsrc/golchk/'
DB_PATH = PATH + 'live.db'
PS_RD = true
PS_RW = false
TOPPAGE_URL = "http://golf.shinh.org/"
ENTRIES_URL = TOPPAGE_URL + "recent.rb"
ENTRIES_XPATH = "/html/body/table/tr"
ACTIVE_PROBLEMS_XPATH = "/html/body/ul[1]/li/a"
RECENT_ENDLESS_PROBLEMS_XPATH = "/html/body/ul[3]/li/a"

Entry = Struct.new(:problem_name, :problem_url, :rank, :user, :language, :size, :score, :time, :date)

def get_xml(url)
  page = open(url){|f| f.read }
  tree = HTree.parse(page)
  xml = tree.to_rexml
end

def same_entry(lhs, rhs)
  lhs.problem_name == rhs.problem_name &&
  lhs.language == rhs.language
end

lastdate = nil
tw_user = ""
tw_pass = ""

db = PStore.new(DB_PATH)
db.transaction(PS_RD) do
  lastdate = db[:lastdate]
  tw_user = db[:tw_user]
  tw_pass = db[:tw_pass]
end

eliminations = ["hello world"]

toppage_xml = get_xml(TOPPAGE_URL)
actives = REXML::XPath.match(toppage_xml, ACTIVE_PROBLEMS_XPATH)
eliminations += actives.map{|e| e.text }

recents = REXML::XPath.match(toppage_xml, RECENT_ENDLESS_PROBLEMS_XPATH)
eliminations += recents.map{|e| e.text }

entries_xml = get_xml(ENTRIES_URL)
entries = REXML::XPath.match(entries_xml, ENTRIES_XPATH)
entries.shift() # remove front element that is item names

entries.map! do |entry|
  problem, rank, user, lang, size, score, time, date = entry.children
  problem_name = problem.children.first.text
  problem_url = problem.children.first.attribute('href')
  rank = rank.text.to_i
  user = user.text
  lang = lang.children.first.text
  size = size.text.to_i
  score = score.text.to_i
  time = time.text.to_f
  date = Time.local(*date.text.scan(/\d+/))
  Entry.new(problem_name, problem_url, rank, user, lang, size, score, time, date)
end

newentries, oldentries = entries, []
newentries, oldentries = entries.partition{|entry| lastdate < entry.date } if lastdate

exit if newentries.size == 0

db.transaction(PS_RW) do
  db[:lastdate] = newentries.first.date
end

entries.delete_if{|entry| entry.rank != 1 }
newentries.delete_if{|entry| entry.rank != 1 }

# remove entries that was updated recently
newentries.delete_if do |new|
  oldentries.find{|old| same_entry(new, old) }
end

# remove old entries where same exist in 'newentries'
tmp = []
newentries.each do |e|
  tmp << e if !tmp.find{|t| same_entry(e, t) }
end
newentries = tmp

# remove active problems & recent endless problems
newentries.delete_if do |new|
  eliminations.find{|problem_name| problem_name = new.problem_name }
end

if !newentries.empty?
  require PATH + 'tw'
  tw = Tw.new(tw_user, tw_pass)
  tw.connect do
    newentries.each do |entry|
      tw.say("%s submits %dB of %s for %s" % [entry.user, entry.size, entry.language, entry.problem_name])
    end
  end
end

