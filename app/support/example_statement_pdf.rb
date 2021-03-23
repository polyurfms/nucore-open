# frozen_string_literal: true

class ExampleStatementPdf < StatementPdf

  def generate(pdf)
    generate_document_header(pdf)
    # generate_contact_info(pdf) if @facility.has_contact_info?
    # generate_remittance_information(pdf) if @account.remittance_information.present?
    generate_order_detail_rows(pdf)
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

  def generate_document_footer(pdf)
    # pdf.number_pages "Page <page> of <total>", at: [0, -15]
    # pdf.markup("<img src='"+"#{Rails.root}/app/assets/images/stamp.png"+"' width='100%' height='100%' style='float:right'>")
    
    pdf.move_down(40)
    pdf.image "#{Rails.root}/app/assets/images/stamp.png",:width => 150 ,:position => :right
    pdf.move_down(10)
    pdf.text "University Research Facility in Life Sciences", size: 13, align: :right
    pdf.move_down(10)
    pdf.markup("<p><u><b>Payment Methods:<b><u></p>")
    pdf.move_down(10)

    pdf.indent(20) do
      pdf.markup("<p><strong> 1. By Cheque</strong></p>")
    end
    
    pdf.move_down(20)
    
    pdf.indent(40) do
      pdf.markup("<p>Send a crossed cheque made payable to &ldquo;The Hong Kong Polytechnic University&rdquo; to the following address and write the invoice no. <strong>ULS 002523</strong> at the back of the cheque.</p>")
      pdf.move_down(20)
      pdf.markup("<p>Address:</p>")
      pdf.markup("<p>Research Office</p>")
      pdf.markup("<p>Room Z404, 4/F, Block Z</p>")
      pdf.markup("<p>The Hong Kong Polytechnic University, Hung Hom, Kowloon</p>")
      pdf.markup("<p>Attn: Stella Wong</p>")
    end

    pdf.move_down(20)

    pdf.indent(20) do
      pdf.markup("<p><strong> 2. By Bank Transfer</strong></p>")
    end
    
    
    pdf.indent(40) do
      pdf.markup("<p>For enquiries, please contact Miss Stella Wong by email at stella-sw.wong@polyu.edu.hk or by phone at 3400 3633.</p>")
      pdf.markup("<p>Transfer payment to the following bank account with the payee name &ldquo;The Hong Kong Polytechnic University&rdquo;</p>")
      pdf.markup("<p>Bank Name: Hang Seng Bank Limited</p>")
      pdf.markup("<p>Bank Account No.: 024-280-277476-001</p>")
      pdf.markup("<p>Details of Payment: Please indicate the invoice no. <strong>ULS 002523</strong> for our reference.</p>")
      pdf.move_down(20)
      pdf.markup("<p>After the payment, please send us a copy of the bank advice by email at <a href='mailto:stella-sw.wong@polyu.edu.hk' style='color:#0563c1; text-decoration:underline'>stella-sw.wong@polyu.edu.hk</a> for follow-up action.&nbsp;</p>")
    end
    pdf.move_down(10)
    pdf.markup("<p>For enquiries, please contact Miss Stella Wong by email at stella-sw.wong@polyu.edu.hk or by phone at 3400 3633.</p>")

  end

  def generate_document_header(pdf)

    date = Time.zone.now.strftime("%Y-%m-%d")
    pdf.font_size = 10.5

    pdf.image "#{Rails.root}/app/assets/images/"+Settings.statement_pdf.header_logo, :at => [0,700], :width => 300 

    pdf.move_down(10)
    pdf.stroke_color '000000'
    pdf.stroke_horizontal_rule
    pdf.move_down(15)
    pdf.text "INVOICE", size: 13, font_style: :bold, align: :center
    pdf.move_down(5)

    table_data = [["To:  " + "Dept of Chemistry, HKBU" , "Invoice No.: " + Settings.statement_pdf.invoice_no_start + " " + "#{@statement.invoice_number}"], 
                  ["Attn: " + "#{@account.owner.user.full_name(suspended_label: false)}", "Date: " + "#{date}"]]
    
    pdf.table(table_data, :width => 500, :cell_style => { :inline_format => true }) do
      style(rows(0..-1), :padding => [0, 0, 0, 0], :borders => [])
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
      column(1).width = 225
      column(2).width = 75
      column(2).style(align: :right)
      column(3).style(align: :right)
    end
  end

  def generate_remittance_information(pdf)
    pdf.move_down(10)
    pdf.text "Bill To:", font_style: :bold
    pdf.text normalize_whitespace(@account.remittance_information)
  end

  def order_detail_headers
    ["Fulfillment Date", "Order", "Quantity", "Amount"]
    # ["Item", "Booking ID", "User", "Description", "Date", "Subtotal (HKD)"]
  end

  def order_detail_rows
    @statement.order_details.includes(:product).order("fulfilled_at DESC").map do |order_detail|
      [
        format_usa_datetime(order_detail.fulfilled_at),
        "##{order_detail}: #{order_detail.product}" + (order_detail.note.blank? ? "" : "\n#{normalize_whitespace(order_detail.note)}"),
        OrderDetailPresenter.new(order_detail).wrapped_quantity,
        number_to_currency(order_detail.actual_total),
      ]
    end
  end

end
