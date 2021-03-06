require 'spec_helper'

describe QuoteRequest, quote_request_spec: true, story_78: true do
  let(:quote_request) { create :quote_request }
  let(:imprintable_1) { create(:valid_imprintable) }
  let(:imprintable_2) { create(:valid_imprintable) }
  let(:user) { create(:user) }

  before do
    allow_any_instance_of(QuoteRequest).to receive(:enqueue_link_integrated_crm_contacts) { |qr|
      qr.link_with_insightly
      qr.link_with_freshdesk
    }
  end

  describe 'Fields' do
    it { is_expected.to have_db_column(:name).of_type(:string) }
    it { is_expected.to have_db_column(:email).of_type(:string) }
    it { is_expected.to have_db_column(:date_needed).of_type(:datetime) }
    it { is_expected.to have_db_column(:description).of_type(:text) }
    it { is_expected.to have_db_column(:source).of_type(:string) }

    it { is_expected.to have_db_column(:created_at).of_type(:datetime) }
    it { is_expected.to have_db_column(:updated_at).of_type(:datetime) }

    it { is_expected.to have_db_column(:status).of_type(:string) }
  end

  describe 'Validations' do
    context 'when status == "could_not_quote"', story_472: true do
      before { subject.status = 'could_not_quote' }
      it { is_expected.to validate_presence_of :reason }
    end
    context 'when status != "could_not_quote"', story_472: true do
      before { subject.status = 'pending' }
      it { is_expected.to_not validate_presence_of :reason }
    end
  end

  describe 'format_phone(num)', story_646: true do
    let(:quote_request) { create :quote_request }
      it 'properly formats phone numbers to the freshdesk required format: +1-xxx-xxx-xxxx' do
        expect(quote_request.format_phone('+1-734-274-2659')).to eq('+1-734-274-2659')
        expect(quote_request.format_phone('17342742659')).to eq('+1-734-274-2659')
        expect(quote_request.format_phone('734-274-2659')).to eq('+1-734-274-2659')
        expect(quote_request.format_phone('7342742659')).to eq('+1-734-274-2659')
        expect(quote_request.format_phone('2742659')).to eq('+1-734-274-2659')
        expect(quote_request.format_phone('12742659')).to eq('+1-734-274-2659')
        expect(quote_request.format_phone('112742659')).to eq('+1-734-274-2659')
      end
  end

  describe 'Freshdesk', freshdesk: true, story_512: true do
    let(:dummy_client) { Object.new }
    let(:dummy_contact) { { user: { id: 123 } } }
    let(:dummy_customer) { { customer: { name: 'test org', id: 555 } } }

    describe '#create_freshdesk_ticket', story_726: true do
      before do
        allow(quote_request).to receive(:freshdesk_description)
          .and_return '<div>hi</div>'.html_safe

        allow(quote_request).to receive(:freshdesk).and_return dummy_client
        allow(quote_request).to receive(:freshdesk_group_id).and_return 54321
        allow(quote_request).to receive(:freshdesk_department).and_return 'Testing'
        allow(quote_request).to receive(:save).with validate: false
        allow(quote_request).to receive(:freshdesk_contact_id).and_return 123
      end

      it 'creates a freshdesk ticket without a quote id and assigns freshdesk_ticket_id' do
        expect(dummy_client).to receive(:post_tickets)
          .with(helpdesk_ticket: {
            source: 2,
            group_id: 54321,
            ticket_type: 'Lead',
            subject: "Information regarding your quote request (##{quote_request.id}) from the Ann Arbor T-shirt Company",
            description_html: anything,
            requester_id: 123
          })
          .and_return({ helpdesk_ticket: { display_id: 998 } }.to_json)

        quote_request.create_freshdesk_ticket
        expect(quote_request.freshdesk_ticket_id).to eq '998'
      end
    end

    context 'when created' do
      context 'and there exists a contact with a matching email on Freshdesk' do
        before(:each) do
          expect(dummy_client).to receive(:get_users)
            .with(query: 'email is test@test.com')
            .and_return [dummy_contact].to_json

          # expect(dummy_client).to receive(:get_companies)
            # .with(letter: 't')
            # .and_return [dummy_customer].to_json

          allow(subject).to receive(:freshdesk).and_return dummy_client
        end

        it 'finds that contact and assigns its id to freshdesk_contact_id' do
          subject.approx_quantity = 1
          subject.date_needed = 2.weeks.from_now
          subject.source = 'rspec'
          subject.description = 'PLEASE, SOME SHIRTS'
          subject.name = 'what'

          subject.email = 'test@test.com'
          subject.organization = 'test org'
          subject.salesperson_id = create(:user).id
          subject.save
          expect(subject.status).to eq 'assigned'
          expect(subject).to be_valid
          expect(subject.reload.freshdesk_contact_id).to eq 123
        end
      end

      context 'and there is no matching-email contact on freshdesk' do
        before(:each) do
          expect(dummy_client).to receive(:get_users)
            .and_return [].to_json

          expect(dummy_client).to receive(:get_companies)
            .with(letter: 't')
            .and_return [].to_json

          expect(dummy_client).to receive(:post_companies)
            .with(
              customer: { name: 'test org' }
            )
            .and_return dummy_customer.to_json

          expect(dummy_client).to receive(:post_users)
            .with(
              user: {
                name: 'what',
                email: 'test@test.com',
                phone: anything,
                customer_id: 555
              }
            )
            .and_return dummy_contact.to_json

          allow(subject).to receive(:freshdesk).and_return dummy_client
        end

        it 'creates one' do
          subject.approx_quantity = 1
          subject.date_needed = 2.weeks.from_now
          subject.source = 'rspec'
          subject.description = 'PLEASE, SOME SHIRTS'
          subject.name = 'what'

          subject.email = 'test@test.com'
          subject.organization = 'test org'
          subject.salesperson_id = create(:user).id
          subject.save
          expect(subject.status).to eq 'assigned'
          expect(subject).to be_valid
          expect(subject.reload.freshdesk_contact_id).to eq 123
        end
      end
    end
  end

  describe 'Insightly', insightly: true, story_513: true do
    context 'when created' do
      let(:dummy_contact) { Object.new }
      let(:dummy_client) { Object.new }
      let(:dummy_organisation) { Struct.new(:organisation_name, :organisation_id) }

      context 'and there exists a contact with a matching email on Insightly' do
        before(:each) do
          expect(dummy_client).to receive(:get_contacts)
            .with(email: 'test@test.com')
            .and_return [dummy_contact]

          expect(dummy_contact).to receive(:contact_id).and_return 123

          allow(subject).to receive(:insightly).and_return dummy_client
        end

        it 'finds that contact and assigns its id to insightly_contact_id' do
          subject.approx_quantity = 1
          subject.date_needed = 2.weeks.from_now
          subject.source = 'rspec'
          subject.description = 'shirts now pls'
          subject.name = 'who cares'

          subject.email = 'test@test.com'
          subject.phone_number = '(123)-123-1233'
          subject.organization = 'test org'
          subject.salesperson_id = create(:user).id
          subject.save
          expect(subject.status).to eq 'assigned'
          expect(subject).to be_valid
          expect(subject.reload.insightly_contact_id).to eq 123
        end
      end

      context 'and there is no matching-email contact on insightly' do
        context 'and no existing organization exists' do
          before(:each) do
            subject.approx_quantity = 1
            subject.date_needed = 2.weeks.from_now
            subject.source = 'rspec'
            subject.description = 'shirts now pls'
            subject.name = 'who cares'

            subject.email = 'test@test.com'
            subject.phone_number = '(123)-123-1233'
            subject.salesperson_id = create(:user).id

            dummy_contact = Object.new
            dummy_client = Object.new
            expect(dummy_client).to receive(:get_contacts)
              .with(email: 'test@test.com')
              .and_return []

            allow(dummy_contact).to receive(:contact_id).and_return 321

            allow(subject).to receive(:insightly).and_return dummy_client

            expect(dummy_client).to receive(:get_organisations)
              .and_return [
                dummy_organisation.new('irrelevant', 1),
                dummy_organisation.new('also irrelevant', 2),
              ]

            expect(dummy_client).to receive(:create_organisation)
              .with(organisation: {
                  organisation_name: 'test org'
                })
              .and_return(dummy_organisation.new('test org', 4))

            expect(dummy_client).to receive(:create_contact)
              .with(contact: {
                first_name: 'who',
                last_name: 'cares',
                contactinfos: [
                  { type: 'EMAIL', detail: 'test@test.com' },
                  { type: 'PHONE', detail: '(123)-123-1233' }
                ],
                links: [{ organisation_id: 4 }]
              })
              .and_return dummy_contact
          end

          it 'creates one and links it' do
            subject.organization = 'test org'
            subject.save
            expect(subject.status).to eq 'assigned'
            expect(subject).to be_valid
            expect(subject.reload.insightly_contact_id).to eq 321
          end
        end

        context 'and an existing organization exists' do
          before(:each) do
            subject.approx_quantity = 1
            subject.date_needed = 2.weeks.from_now
            subject.source = 'rspec'
            subject.description = 'shirts now pls'
            subject.name = 'who cares'

            subject.email = 'test@test.com'
            subject.phone_number = '(123)-123-1233'
            subject.salesperson_id = create(:user).id

            dummy_contact = Object.new
            dummy_client = Object.new
            expect(dummy_client).to receive(:get_contacts)
              .with(email: 'test@test.com')
              .and_return []

            allow(dummy_contact).to receive(:contact_id).and_return 321

            allow(subject).to receive(:insightly).and_return dummy_client

            expect(dummy_client).to receive(:get_organisations)
              .and_return [
                dummy_organisation.new('irrelevant', 1),
                dummy_organisation.new('also irrelevant', 2),
                dummy_organisation.new('Test org', 3),
              ]

            expect(dummy_client).to receive(:create_contact)
              .with(contact: {
                first_name: 'who',
                last_name: 'cares',
                contactinfos: [
                  { type: 'EMAIL', detail: 'test@test.com' },
                  { type: 'PHONE', detail: '(123)-123-1233' }
                ],
                links: [{ organisation_id: 3 }]
              })
              .and_return dummy_contact
          end

          it 'links it' do
            subject.organization = 'test org'
            subject.save
            expect(subject.status).to eq 'assigned'
            expect(subject).to be_valid
            expect(subject.reload.insightly_contact_id).to eq 321
          end
        end
      end
    end
  end

  describe 'status', story_195: true do
    context 'on creation' do
      it 'is "pending"' do
        quote_request = QuoteRequest.create(
          name: 'cool guy',
          email: 'cool@guy.com',
          approx_quantity: 15,
          date_needed: Time.now + 2.weeks,
          description: 'Hey man, I need some SHIRTS',
          source: 'RSpec'
        )
        expect(quote_request).to be_valid
        expect(quote_request.status).to eq 'pending'
      end
    end
  end

  describe '#salesperson_id=' do
    let(:delayed_send_assigned_email) { double('delayed task') }

    it 'sets status to "assigned"', story_195: true do
      quote_request.salesperson_id = user.id
      quote_request.save
      expect(quote_request.reload.status).to eq 'assigned'
    end

    it 'delays a task that sends out an email to the new salesperson', pending: "delaying emails has been temporarily removed", story_725: true do
      expect(delayed_send_assigned_email).to receive(:send_assigned_email).with(user.id)
      expect(quote_request).to receive(:delay).and_return delayed_send_assigned_email

      quote_request.salesperson_id = user.id
      quote_request.save
    end
  end

  describe '#imprintable_quantities=', imprintable_quantities: true do
    context 'given a hash of imprintable_id => quantity' do
      let!(:input) { { imprintable_1.id => 1, imprintable_2.id => 5 } }

      it 'adds QuoteRequestImprintables with the given quantities to the quote request' do
        quote_request.imprintable_quantities = input
        expect(quote_request.save).to eq true
        expect(quote_request.quote_request_imprintables.where(imprintable_id: imprintable_1.id, quantity: 1)).to exist
        expect(quote_request.quote_request_imprintables.where(imprintable_id: imprintable_2.id, quantity: 5)).to exist
      end

      it 'ignores 0 quantity entries' do
        input[imprintable_1.id] = 0
        quote_request.imprintable_quantities = input
        expect(quote_request.save).to eq true
        expect(quote_request.quote_request_imprintables.where(imprintable_id: imprintable_1.id))
          .to_not exist
      end
    end

    context 'given a json string' do
      let!(:input) { { imprintable_1.id => 1, imprintable_2.id => 5 }.to_json }

      it 'works' do
        quote_request.imprintable_quantities = input
        expect(quote_request.save).to eq true
      end
    end
  end

  describe '#send_assigned_email', story_725: true do
    let(:dummy_mail) { double('email', deliver: true) }

    before do
      quote_request.salesperson_id = user.id and quote_request.save!
    end

    context "when the given user id doesn't match salesperson_id (indicating another change was made)" do
      it 'does nothing' do
        expect(QuoteRequestMailer).to_not receive(:notify_salesperson_of_quote_request_assignment)
        quote_request.send_assigned_email(user.id + 1)
      end
    end
    context 'when the given user id == salesperson_id' do
      it 'sends QuoteRequestMailer.notify_salesperson_of_quote_request_assignment' do
        expect(QuoteRequestMailer).to receive(:notify_salesperson_of_quote_request_assignment)
          .and_return dummy_mail
        quote_request.send_assigned_email(user.id)
      end
    end
  end

  describe 'when status is changed', no_ci: true, story_271: true do
    it 'creates a public activity with params s: status_changed_from/to', retry: 2 do
      quote_request.status = 'requested_info'
      PublicActivity.with_tracking do
        quote_request.save
        activity = quote_request.activities.first

        expect(activity.parameters['s']).to be_a Hash
        expect(activity.parameters['s']['status_changed_from']).to eq 'pending'
        expect(activity.parameters['s']['status_changed_to']).to eq 'requested_info'
      end
    end
  end
end
