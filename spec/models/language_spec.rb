describe Language do
  it { should have_and_belong_to_many :tracks }
  it { should have_many :courses }
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:level) }

  describe 'active scope' do
    it 'returns all languages that are not archived' do
      language = FactoryBot.create(:language, name: 'A Language', level: 1)
      archived_language = FactoryBot.create(:language, name: 'Archived Language', level: 1, archived: true)
      expect(Language.active).to eq [language]
    end
  end
end
