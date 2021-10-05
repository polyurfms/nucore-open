# frozen_string_literal: true

class ExampleStatementPdf < StatementPdf

  def generate(pdf)
    #@invoice_number = @facility.abbreviation + " " + @statement.invoice_number
    @invoice_number = @statement.ref_no
    @enquiry_person = Settings.statement_pdf.enquiry_person
    @contact_name = Settings.statement_pdf.contact_name

    @email = Settings.statement_pdf.email
    @phone = Settings.statement_pdf.phone
    @bank_name = Settings.statement_pdf.bank_name
    @bank_account = Settings.statement_pdf.bank_account
    @payee = Settings.statement_pdf.payee
    @address_1 = Settings.statement_pdf.address_1
    @address_2 = Settings.statement_pdf.address_2
    @address_3 = Settings.statement_pdf.address_3

    generate_document_header(pdf)
    # generate_contact_info(pdf) if @facility.has_contact_info?
    # generate_remittance_information(pdf) if @account.remittance_information.present?
    generate_order_detail_rows(pdf)
    generate_document_payment(pdf)
    generate_document_footer(pdf)
  end

  private

  def generate_contact_info(pdf)
    pdf.text @facility.address if @facility.address
    pdf.move_down(10)

    %w(phone_number fax_number email).each do |contact_field|
      field_value = @facility.send(contact_field.to_sym)
      next if field_value.blank?
      pdf.text "<b>#{contact_field.titleize}:</b> #{field_value}", inline_format: true
    end
  end

  def generate_document_payment(pdf)
    pdf.move_down(40)
    pdf.markup("<p><u><b>Payment Methods:<b><u></p>")
    pdf.move_down(10)

    pdf.indent(20) do
      pdf.markup("<p><strong> 1. By Cheque</strong></p>")
    end

#    pdf.move_down(20)

    pdf.indent(40) do
      pdf.markup("<p>Send a crossed cheque made payable to &ldquo;"+@payee+"&rdquo; to the following address and write the invoice no. <strong>"+@invoice_number+"</strong> at the back of the cheque.</p>")
      # pdf.move_down(20)
      pdf.markup("<p>Address:</p>")
      pdf.markup("<p>"+@address_1+"</p>")
      pdf.markup("<p>"+@address_2+"</p>")
      pdf.markup("<p>"+@address_3+"</p>")
      pdf.markup("<p>Attn: "+@contact_name+"</p>")
    end

    pdf.move_down(20)

    pdf.indent(20) do
      pdf.markup("<p><strong> 2. By Bank Transfer</strong></p>")
    end

    pdf.indent(40) do
      pdf.markup("<p>Transfer payment to the following bank account with the payee name &ldquo;"+@payee+"&rdquo;</p>")
      pdf.markup("<p>Bank Name: "+@bank_name+"</p>")
      pdf.markup("<p>Bank Account No.: "+@bank_account+"</p>")
      pdf.markup("<p>Details of Payment: Please indicate the invoice no. <strong>"+@invoice_number+"</strong> for our reference.</p>")
      # pdf.move_down(20)
      pdf.markup("<p>After the payment, please send us a copy of the bank advice by email at <u>"+@email+"</u> for follow-up action.&nbsp;</p>")
    end
    pdf.move_down(10)
    pdf.markup("<p>For enquiries, please contact "+@enquiry_person+" by email at <u>"+@email+"</u> or by phone at "+@phone+".</p>")
  end

  def generate_document_footer(pdf)
    #pdf.stroke_horizontal_rule
    pdf.number_pages "Page <page> of <total>", at: [0, -15], align: :right
  end

  def generate_document_header(pdf)

    date = Time.zone.now.strftime("%d %b %Y")
    pdf.font_size = 10.5

    pdf.image "#{Rails.root}/app/assets/images/statement-logo.jpg", :at => [0,700], :width => 200
    pdf.draw_text  @facility.abbreviation , size: 24, font_style: :bold, :at => [425,675]
    pdf.move_down(10)
    pdf.stroke_color '000000'
    pdf.stroke_horizontal_rule
    pdf.move_down(15)
    pdf.text "INVOICE", size: 13, font_style: :bold, align: :center
    pdf.move_down(5)

    if @account.remittance_information.present?
      @bill_to = @account.remittance_information
    else
      @bill_to = @account.owner.user.full_name(suspended_label: false)
    end

    table_data = [
                  ["To", ":", "#{@bill_to}" , "Invoice No.",":", "#{@invoice_number}"],
                  ["Attn", ":", "#{@account.attention}", "Date", ":", "#{date}"]]


    # if @account.remittance_information.present?
    #   @bill_to = @account.remittance_information
    # else
    #   @bill_to = @account.owner.user.full_name(suspended_label: false)
    # end

    # table_data = [["From:  " + @facility.name , ""],
    #               ["To:  " + @bill_to , "Invoice No.: " + @invoice_number],
    #               ["Attn: " + "#{@account.owner.user.full_name(suspended_label: false)}", "Date: " + "#{date}"]]

    pdf.table(table_data, :width => 700, :cell_style => { :inline_format => true }) do
      style(rows(0..-1), :padding => [2, 2, 2, 2], :borders => [])

      column(0).width = 30
      column(0).style(align: :right)
      column(1).width = 10
      column(2).width = 310
      column(3).width = 70
      column(3).style(align: :right)

      column(4).width = 10

      column(5).width = 270
      column(5).style(align: :left)

    end
    pdf.move_down(15)
    pdf.text "Dear #{@account.owner.user.full_name(suspended_label: false)}"
    pdf.move_down(5)
    # pdf.text "Our facility has provided access to the following equipment or service to members of your team in January according to our booking record. Please arrange the payment via one of the methods listed below within two weeks from the invoice date. Kindly note that failure to return this invoice by the said date could lead to suspension of all associated online booking accounts."
    pdf.markup(Settings.statement_pdf.html_element)
    # pdf.text @facility.to_s, size: 20, font_style: :bold
    # pdf.text "Invoice ##{@statement.invoice_number}"
    # pdf.text "Account: #{@account}"
    # pdf.text "Owner: #{@account.owner.user.full_name(suspended_label: false)}"
  end

  def generate_order_detail_rows(pdf)
    pdf.move_down(30)
    pdf.table([order_detail_headers] + order_detail_rows, header: true, width: 510) do
      row(0).style(LABEL_ROW_STYLE)
      column(0).width = 125
      column(1).width = 300
      # column(2).style(align: :right)
      column(3).style(align: :right)
    end
    pdf.move_down(10)

    pdf.draw_text  "Total : #{number_to_currency(@statement.total_cost)}" , at: [398, pdf.cursor]
#    pdf.text "Total: "+number_to_currency(@statement.total_cost), align: :right
#    pdf.text "Total: "+number_to_currency(@statement.total_cost), align: :right

  end

#  def generate_remittance_information(pdf)
#    pdf.move_down(10)
#    pdf.text "Bill To:", font_style: :bold
#    pdf.text normalize_whitespace(@account.remittance_information)
#  end

  def order_detail_headers
    ["Fulfillment Date", "Order", "Amount \n (HKD)"]
    # ["Fulfillment Date", "Order", "Quantity", "Amount"]
    # ["Item", "Booking ID", "User", "Description", "Date", "Subtotal (HKD)"]
  end

  def order_detail_rows
    @statement.order_details.includes(:product).order("fulfilled_at DESC").map do |order_detail|
      [
        format_usa_datetime(order_detail.fulfilled_at),
        "##{order_detail}: #{order_detail.product}" + (order_detail.note.blank? ? "" : "\n#{normalize_whitespace(order_detail.note)}"),
        # OrderDetailPresenter.new(order_detail).wrapped_quantity,
        number_to_currency(order_detail.actual_total),
      ]
    end
  end

end
