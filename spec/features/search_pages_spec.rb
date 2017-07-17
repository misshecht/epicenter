feature 'searching for a student' do
  scenario 'as a guest' do
    visit students_path
    expect(page).to have_content 'You need to sign in.'
  end

  scenario 'as a student' do
    student = FactoryGirl.create(:user_with_all_documents_signed)
    login_as(student, scope: :student)
    visit students_path
    expect(page).to have_content 'Your courses'
  end

  context 'as an admin' do
    let(:admin) { FactoryGirl.create(:admin) }
    before do
      allow_any_instance_of(Student).to receive(:update_close_io)
      login_as(admin, scope: :admin)
    end

    scenario 'when no query is made' do
      visit students_path
      click_on 'student-search'
      expect(page).to have_content 'No students found.'
    end

    scenario 'when a query is made for an archived student' do
      archived_student = FactoryGirl.create(:student)
      Enrollment.find_by(student: archived_student).destroy
      archived_student.destroy
      visit root_path
      within '#navbar-search' do
        fill_in 'search', with: archived_student.name
        click_on 'student-search'
      end
      expect(page).to have_content archived_student.name
      expect(page).to have_content 'Archived'
    end

    scenario 'when a query is made for an unenrolled student' do
      unenrolled_student = FactoryGirl.create(:student)
      Enrollment.find_by(student: unenrolled_student).destroy
      visit root_path
      within '#navbar-search' do
        fill_in 'search', with: unenrolled_student.name
        click_on 'student-search'
      end
      expect(page).to have_content unenrolled_student.name
      expect(page).to have_content 'Not enrolled'
    end

    scenario 'when a query is made for a current student' do
      student = FactoryGirl.create(:student)
      visit root_path
      within '#navbar-search' do
        fill_in 'search', with: student.name
        click_on 'student-search'
      end
      expect(page).to have_content student.name
      expect(page).to have_content 'Current student'
    end

    scenario 'when a query is made for a future student' do
      course = FactoryGirl.create(:future_course)
      student = FactoryGirl.create(:student, courses: [course])
      visit root_path
      within '#navbar-search' do
        fill_in 'search', with: student.name
        click_on 'student-search'
      end
      expect(page).to have_content student.name
      expect(page).to have_content 'Future student'
    end

    scenario 'when a query is made for a student who has graduated' do
      course = FactoryGirl.create(:internship_course)
      past_student = FactoryGirl.create(:user_with_all_documents_signed, courses: [course])
      visit root_path
      travel_to past_student.course.end_date + 1.days do
        within '#navbar-search' do
          fill_in 'search', with: past_student.name
          click_on 'student-search'
        end
        expect(page).to have_content past_student.name
        expect(page).to have_content 'Graduate'
      end
    end

    scenario 'when a query is made for an existing student with a payment made', :vcr, :stripe_mock, :stub_mailgun do
      in_class_student = FactoryGirl.create(:user_with_all_documents_signed_and_credit_card, email: 'example@example.com')
      FactoryGirl.create(:payment_with_credit_card, student: in_class_student)
      visit root_path
      within '#navbar-search' do
        fill_in 'search', with: in_class_student.name
        click_on 'student-search'
      end
      expect(page).to have_content in_class_student.name
      expect(page).to have_content 'Current student'
    end

    scenario 'when a query is made for a student who withdrew' do
      past_student = FactoryGirl.create(:user_with_all_documents_signed)
      visit root_path
      travel_to past_student.course.end_date + 1.days do
        within '#navbar-search' do
          fill_in 'search', with: past_student.name
          click_on 'student-search'
        end
        expect(page).to have_content past_student.name
        expect(page).to have_content 'Incomplete'
      end
    end

    scenario 'when a query is made for a student who finished before 2016' do
      course = FactoryGirl.create(:course, class_days: [Time.new(2015, 1, 1).to_date])
      student = FactoryGirl.create(:student, courses: [course])
      visit root_path
      within '#navbar-search' do
        fill_in 'search', with: student.name
        click_on 'student-search'
      end
      expect(page).to have_content student.name
      expect(page).to have_content 'Pre-2016'
    end

    scenario 'when a query is made for a part-time student' do
      course = FactoryGirl.create(:part_time_course, class_days: [Time.zone.now.to_date.monday])
      student = FactoryGirl.create(:student, courses: [course])
      visit root_path
      within '#navbar-search' do
        fill_in 'search', with: student.name
        click_on 'student-search'
      end
      expect(page).to have_content student.name
      expect(page).to have_content 'Part-time'
    end
  end
end
