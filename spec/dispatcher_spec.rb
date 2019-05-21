# frozen_string_literal: true

require 'spec_helper'

describe ActAsNotified::Dispatcher do
  it 'should find scope by alert' do
    ActAsNotified.configure do
      scope :s1 do
        alert(:foo) {}
      end
    end

    dispatcher = ActAsNotified::Dispatcher.new(
      ActAsNotified.configuration,
      :foo,
      ActAsNotified::Samples::S1Payload.new
    )

    expect(dispatcher.alert).not_to be_nil
    expect(dispatcher.alert.name).to eq(:foo)
    expect(dispatcher.scope).not_to be_nil
    expect(dispatcher.scope.name).to eq(:s1)
  end

  it 'should find all recipients' do
    ActAsNotified.configure do
      scope :s1 do
        alert(:foo) do
          notify(:users)
        end
      end
    end

    dispatcher = ActAsNotified::Dispatcher.new(
      ActAsNotified.configuration,
      :foo,
      ActAsNotified::Samples::S1Payload.new
    )

    expect(dispatcher.notifiers).not_to be_nil
    expect(dispatcher.notifiers.count).to eq(1)
    expect(dispatcher.notifiers[:users]).not_to be_nil
    expect(dispatcher.notifiers[:slack]).to be_nil
  end

  it 'should call scope to fetch recipients' do
    ActAsNotified.configure do
      scope :s1 do
        alert(:foo) do
          notify(:users)
        end
      end
    end

    dispatcher = ActAsNotified::Dispatcher.new(
      ActAsNotified.configuration,
      :foo,
      ActAsNotified::Samples::S1Payload.new
    )

    expect(dispatcher.notifiers).not_to be_nil
    expect(dispatcher.notifiers.count).to eq(1)
    expect(dispatcher.notifiers[:users]).not_to be_nil
    expect(dispatcher.notifiers[:slack]).to be_nil
  end

  it 'should fetch all recipients' do
    class Scope1
      def users(_payload)
        %i[bar fuzz]
      end
    end

    ActAsNotified.configure do
      scope :s1, klass: Scope1 do
        alert :foo do
          notify :users
        end
      end
    end

    dispatcher = ActAsNotified::Dispatcher.new(
      ActAsNotified.configuration,
      :foo,
      ActAsNotified::Samples::S1Payload.new
    )

    expect(dispatcher.recipients(:users)).not_to be_nil
    expect(dispatcher.recipients(:users).count).to eq(2)
  end

  it 'should filter recipients' do
    class Recipient
      attr_accessor :id

      def initialize(id)
        @id = id
      end
    end
    rec = [Recipient.new(1), Recipient.new(2)]
    class Scope1
      def users(_payload)
        rec
      end
    end
    ActAsNotified.configure do
      channel(:email) {}
      scope :s1, klass: Scope1 do
        alert :foo do
          notify(:users).on(:default)
        end
      end
    end

    dispatcher = ActAsNotified::Dispatcher.new(
      ActAsNotified.configuration,
      :foo,
      ActAsNotified::Samples::S1Payload.new
    )

    # no opt ins yet
    expect(dispatcher.filter_recipients(rec, :email).count).to eq(0)

    # opt in one user
    ActAsNotified.opt_in_provider.opt_in(scope: :s1, entity_id: 2, alert_name: :foo, channel_name: :email)

    # confirm the opt in
    expect(ActAsNotified.opt_in_provider.opted_in?(scope: :s1, entity_id: 2, alert_name: :foo, channel_name: :email)).to be_truthy

    # we should have 1 user in now
    expect(dispatcher.filter_recipients(rec, :email).count).to eq(1)
    expect(dispatcher.filter_recipients(rec, :email)[0]).to equal(rec[1])
  end

  it 'should dispatch' do
    class Recipient
      attr_accessor :id

      def initialize(id)
        @id = id
      end
    end

    class Scope1
      def users(_payload)
        [Recipient.new(1), Recipient.new(2)]
      end
    end

    class Email
      def new_signup(recipients, payload)
        raise ActAsNotified::Error, 'bad recipients' unless recipients.count == 1
        raise ActAsNotified::Error, 'bad payload' unless payload.is_a? ActAsNotified::Samples::S1Payload
      end
    end

    ActAsNotified.configure do
      channel(:email, klass: Email) {}
      scope :scope1, klass: Scope1 do
        alert :new_signup do
          notify(:users).on(:default)
        end
      end
    end

    pl = ActAsNotified::Samples::S1Payload.new
    dispatcher = ActAsNotified::Dispatcher.new(
      ActAsNotified.configuration,
      :new_signup,
      pl
    )

    ActAsNotified.opt_in_provider.opt_in(scope: :scope1, entity_id: 1, alert_name: :new_signup, channel_name: :email)
    expect(ActAsNotified.opt_in_provider.opted_in?(scope: :scope1, entity_id: 1, alert_name: :new_signup, channel_name: :email)).to be_truthy

    dispatcher.dispatch
  end

end