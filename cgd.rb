require 'rubygems'
require 'mechanize'
require 'highline'
require 'pp'

DICT = [
    [/CREPELOVE/, "CREPELOVE", "Food"],
    [/KURZ/, "ALEMAO", "Food"],
    [/JOSHUA'S SHOARMA/, "Isrealita", "Food"],
    [/TRANSACCAO A DEBITO EM ATM/, "MB", "MB"],
    [/CINEMA/, "CINEMA", "FUN"],
    [/PANS & COMPANY/, "Food", "Food"],
    [/CAFE 3 RESTAURACAO/, "H3", "Food"],
    [/RESTAURANTE/, "Food", "Food"],
    [/WOK NAGASAKI/, "Food", "Food"],
    [/WOK TO WALK/, "Food", "Food"],
    [/CASCATA VASCO GAMA RIO DE MOURO/, "Food", "Food"],
    [/M AMELIA E FILHO,LDAERICEIRA/, "Galp Ericeira", "Gas"],
    [/WWW CP PT/, "CP", "Services"],
]

class CaixaGeralDepositos

    def initialize
        @agent = Mechanize.new #TODO certificate handling
        true
    end

    def do_login
        highline = HighLine.new 
        login_page = @agent.get('https://m.caixadirecta.cgd.pt')
        main_page = login_page.form_with(:name => 'Login_execute') do |form|
            form["requestedCredentials.USER_NAME.value"] = highline.ask("Enter your user: " ) { |q| q.echo = "x"}
            form["requestedCredentials.ACCESS_CODE.value"] = highline.ask("Enter your password: " ) { |q| q.echo = "x"}
        end.click_button
        true
    end


    def print_total
        page = @agent.get('https://m.caixadirecta.cgd.pt/pocketBank/PosicaoGlobal.action')
        puts "Total: "
        puts page.links[1].text
    end

    def print_transactions

        puts ["Data".center(8),"Description".center(24), "Montante".center(10)].join("|")

        # link "Movimentos"
        page = @agent.get('https://m.caixadirecta.cgd.pt/pocketBank/PosicaoGlobal.action')
        movimentos = page.links[3].click
        # format html doc to a table
        movimentos.parser.xpath('//table//tr')[4..-1].each do |row|
            cells = row.xpath('td')
            next unless cells.size > 3
            print cells[0].text.strip.center(7)
            print " | "
            print cells[2].text.strip.rjust(22)
            print " | "
            print cells[4].text.strip.rjust(10)
            print " | "
            puts ""
        end
    end

    def match_transactions

        extract_transactions.collect do |trans|

            cur_trans = trans.dup
            classifier = "Others"

            DICT.each do |regex_arr|
                next unless cur_trans[1].match regex_arr.first
                classifier = regex_arr.last
                break
            end
            cur_trans << classifier
        end
    end

    def do_logout
        @agent.get('https://m.caixadirecta.cgd.pt/pocketBank/Logout.action')
    end

    private
    def extract_transactions

        paths = ["/html/body/b[2]", "/html/body/b[6]", "/html/body/b[4]"]
        ret = []

        4.times do |i|
            movimentos = @agent.get("https://m.caixadirecta.cgd.pt/pocketBank/Movimentos.action?searchPeriod=0&page=#{i+1}&queryId=511")
            compras_levs = movimentos.links.select {|p| p.text.strip.match(/^(COMPRA|LEVANTAMENTO)+/) }

            ret = ret + compras_levs.collect  do |compra_page|
                compra = compra_page.click
                paths.collect {|b| compra.parser.xpath(b).text.strip}
            end
        end

        ret

    end
=begin
    Example result dataset
      [
          ["29-11-11", "", "-13,85 EUR", "Others"],
          ["28-11-11", "TRANSACCAO A DEBITO EM ATM:CC Campo Pequ", "-10,00 EUR", "MB"],
          ["26-11-11", "JOSHUA'S SHOARMA 2696-017 ALCABIDEC", "-12,30 EUR", "Food"],
          ["26-11-11", "FARMACIA ALCOITAO LJ 0089-ALCABIDECH", "-4,70 EUR", "Others"],
          ["26-11-11", "CINEMA CASCAIS ESTORIL", "-6,10 EUR", "FUN"],
          ["25-11-11", "CREPELOVE//QUIPIZZA LISBOA", "-14,30 EUR", "Food"],
          ["24-11-11", "MESTRE&MESTRE LDA LISBOA", "-14,50 EUR", "Others"],
          ["23-11-11", "M.V.SOUSA, LDA. 1700 LISBOA", "-19,32 EUR", "Others"]
      ]
=end

end
