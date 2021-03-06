#encoding: utf-8
class Cpanel::LogController < Cpanel::ApplicationController
  set :views, ENV["VIEW_PATH"] + "/cpanel/log"
  set :layout, :"../layouts/layout"
  helpers CpanelLogHelper
  before do
    unless login?
      flash[:warnging] = "please login."
      redirect "/"
    end
  end

  get "/" do
    begin
      file_path = File.join(Setting.mailgates.path.log, "mgmailerd.log")
      @datas = IO.readlines(file_path).last(100).map do |line|
        parse_mailgate_log(line)
      end.reverse
    rescue => e
      @errors = e.backtrace
      @errors.unshift(e.message)
    end

    template = @datas ? :index : :error
    haml template, layout: settings.layout
  end

  # Get /log/other
  get "/other" do
    haml :other, layout: settings.layout
  end

  private
    def parse_mailgate_log(line)
      regexp = /\[(.*?)\]\s+\[(.*?)\] Mail\.RR\s(.*?\s*->\s*.*?)\s\((.*?)\)\[(.*)\]\[(.*?)\]\[(.*?)\]\[(.*?)\]/
      line  = line.force_encoding("UTF-8")
      match = line.scan(regexp) rescue [nil]

      if match[0] and match[0].size == 8
        timestamp, emailfile, from_to, subject, result, mgham, mgtaglog, charset = match[0]
        from, to = from_to.split(/->/).map { |str| str.gsub(/<|>/, "").strip } rescue ["", ""]

        from = from.scan(/.*?_(\d+)_0@(.*)/)[0].join("/") rescue from if from
        to   = to.scan(/.*?_(\d+)_0@(.*)/)[0].join("/") rescue to if to
        if subject.start_with?("Returned Mail:")
          result  = result + "<br>subject: " + subject
          subject = subject.scan(/(Returned\sMail\:\s\w+)/)[0][0]
        elsif subject.start_with?("Warning--")
          result  = result + "<br>subject: " + subject
          subject = "Warning#Mailgates"
        end
        return {timestamp: timestamp.split.last, emailfile: emailfile, from: from, to: to,
         subject: subject, result: result, mgham: mgham, mgtaglog: mgtaglog, charset: charset}
      else
        return {raw: line}
      end
    end
end
