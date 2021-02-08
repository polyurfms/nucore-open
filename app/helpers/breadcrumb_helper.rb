# frozen_string_literal: true

module BreadcrumbHelper

  def order_reservation_breadcrumb
    link_to my_breadcrumb_label, my_breadcrumb_path
  end

  private

  def my_breadcrumb_label
    if @active_tab == "reservations"
      t_my(Reservation)
    elsif @active_tab == "accounts"
      I18n.t("pages.my_payment_sources")
    else
      # t_my(Order)
      I18n.t("pages.my_items")
    end
  end

  def my_breadcrumb_path
    public_send("#{@active_tab}_path")
  end

end
