# frozen_string_literal: true

require 'spec_helper'

describe Noticent::Definitions::Alert do
  it 'should validate fetch' do
    h = Noticent::Definitions::Hooks.new
    expect { h.fetch(:bad) }.to raise_error(::ArgumentError)
    expect { h.fetch(:pre_channel_registration) }.not_to raise_error
  end

  it 'should run the right method' do
    conf = Noticent::Config.new
    s1 = build(:post_payload)
    alert = Noticent::Definitions::Alert.new(conf,
                                             name: :foo,
                                             scope: s1)
    custom_hook = double(:custom_hook)
    allow(custom_hook).to receive(:pre_alert_registration)
    allow(custom_hook).to receive(:post_alert_registration)
    h = Noticent::Definitions::Hooks.new
    h.add(:pre_alert_registration, custom_hook)
    h.run(:pre_alert_registration, alert)

    expect(custom_hook).to have_received(:pre_alert_registration).with(alert)
    expect(custom_hook).not_to have_received(:post_alert_registration).with(alert)
  end

  it 'runs the hooks in the right order' do
    alert = nil
    custom_hook = double(:custom_hook)
    allow(custom_hook).to receive(:pre_alert_registration)
    allow(custom_hook).to receive(:post_alert_registration)

    Noticent.configure do |config|
      config.hooks.add(:pre_alert_registration, custom_hook)
      config.hooks.add(:post_alert_registration, custom_hook)
      config.scope :post do
        alert = alert(:foo) { notify :users }
      end
    end

    expect(custom_hook).to have_received(:pre_alert_registration).with(alert)
    expect(custom_hook).to have_received(:post_alert_registration).with(alert)
  end

  it 'adds notifiers' do
    Noticent.configure do
      scope :post do
        alert(:foo) do
          notify :users
        end
      end
    end
  end

  it 'should support products' do
    Noticent.configure do 
      product :foo 
      product :bar
    end

    alert = Noticent::Definitions::Alert.new(Noticent.configuration, name: :foo, scope: :bar)
    expect(alert.products).not_to be_nil
    expect(alert.products.count).to eq(0)
    alert.applies.to(:foo)
    alert.applies.to(:bar)

    expect(alert.products.count).to eq(2)
  end

  it 'should have defaults' do
    Noticent.configure {}

    alert = Noticent::Definitions::Alert.new(Noticent.configuration, name: :foo, scope: :bar)

    expect(alert.default_value).not_to be_nil
    expect(alert.default_value).not_to be_truthy
  end

  it 'should have channel default' do
    Noticent.configure do
      channel :email
    end

    alert = Noticent::Definitions::Alert.new(Noticent.configuration, name: :foo, scope: :bar)
    expect(alert.default_value).not_to be_nil
    expect(alert.default_value).not_to be_truthy
    expect(alert.default_for(:email)).not_to be_nil
    expect(alert.default_for(:email)).not_to be_truthy
    expect { alert.default_for(:bad_channel) }.to raise_error ArgumentError
  end

  it 'should allow change of default for an alert' do
    Noticent.configure do
      channel :email

      scope :post do
        alert :foo do
          default true
          notify :users
        end
      end
    end

    alert = Noticent.configuration.alerts[:foo]
    expect(alert.default_value).not_to be_nil
    expect(alert.default_value).to be_truthy
    expect(alert.default_for(:email)).not_to be_nil
    expect(alert.default_for(:email)).to be_truthy
  end

  it 'should allow change of default per channel' do
    Noticent.configure do
      channel :email
      channel :slack

      scope :post do
        alert :foo do
          default true do
            on(:email)
          end
          notify :users
        end
      end
    end


    alert = Noticent.configuration.alerts[:foo]
    expect(alert.default_value).not_to be_nil
    expect(alert.default_value).not_to be_truthy
    expect(alert.default_for(:email)).not_to be_nil
    expect(alert.default_for(:email)).to be_truthy
    expect(alert.default_for(:slack)).not_to be_nil
    expect(alert.default_for(:slack)).not_to be_truthy
  end

end
