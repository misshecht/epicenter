feature "print completion certificate" do
  context "before class is over" do
    it "doesn't show link to print certificate" do
      student = FactoryBot.create(:student)
      login_as(student, scope: :student)
      visit edit_student_registration_path
      expect(page).to_not have_link "View certificate of completion"
      expect(page).to have_content "Certificate will be available"
    end

    it "doesn't show certificate even if student directly enters URL" do
      student = FactoryBot.create(:student)
      login_as(student, scope: :student)
      visit certificate_path
      expect(page).to_not have_content "Epicodus Certificate of Completion"
    end

    it "doesn't show certificate even if student directly enters URL" do
      student = FactoryBot.create(:student)
      login_as(student, scope: :student)
      visit student_certificate_path(student)
      expect(page).to_not have_content "Epicodus Certificate of Completion"
    end
  end

  context "after class ends" do
    let(:course) { FactoryBot.create(:course) }
    let(:internship_course) { FactoryBot.create(:internship_course) }
    let(:student) { FactoryBot.create(:student, courses: [course, internship_course]) }
    let(:code_review) { FactoryBot.create(:code_review, course: course) }
    let(:submission) { FactoryBot.create(:submission, code_review: code_review, student: student) }

    context "failing code review" do
      it "doesn't show link to print certificate", :stub_mailgun do
        FactoryBot.create(:failing_review, submission: submission)
        travel_to internship_course.end_date + 1.day do
          login_as(student, scope: :student)
          visit edit_student_registration_path
          expect(page).to_not have_content "View certificate of completion."
          expect(page).to have_content "Certificate will be available"
        end
      end

      it "doesn't show certificate even if student directly enters URL", :stub_mailgun do
        FactoryBot.create(:failing_review, submission: submission)
        travel_to internship_course.end_date + 1.day do
          login_as(student, scope: :student)
          visit certificate_path
          expect(page).to have_content "Certificate not yet available."
        end
      end

      it "doesn't show certificate even if student directly enters URL", :stub_mailgun do
        FactoryBot.create(:failing_review, submission: submission)
        travel_to internship_course.end_date + 1.day do
          login_as(student, scope: :student)
          visit student_certificate_path(student)
          expect(page).to have_content "Certificate not yet available."
        end
      end
    end

    context "all code reviews passing" do
      it "allows student to print certificate", :stub_mailgun do
        FactoryBot.create(:passing_review, submission: submission)
        travel_to internship_course.end_date + 1.day do
          login_as(student, scope: :student)
          visit edit_student_registration_path
          click_link "View certificate of completion"
          expect(page).to have_content "Epicodus Certificate of Completion"
          expect(page).to have_content student.name
        end
      end

      it "does not allow student to view certificate for other students" do
        other_student = FactoryBot.create(:student)
        FactoryBot.create(:passing_review, submission: submission)
        travel_to internship_course.end_date + 1.day do
          login_as(student, scope: :student)
          visit student_certificate_path(other_student)
          expect(page).to have_content student.name
          expect(page).to_not have_content other_student.name
        end
      end
    end
  end

  context "logged in as admin" do
    it "allows super admin to generate certificate" do
      student = FactoryBot.create(:student)
      admin = FactoryBot.create(:admin, super_admin: true)
      travel_to student.course.end_date + 1.day do
        login_as(admin, scope: :admin)
        visit student_courses_path(student)
        click_on 'Manually generate certificate'
        expect(page).to have_content "Epicodus Certificate of Completion"
        expect(page).to have_content student.name
      end
    end

    it "does not allow regular admins to generate certificate" do
      student = FactoryBot.create(:student)
      admin = FactoryBot.create(:admin)
      travel_to student.course.end_date + 1.day do
        login_as(admin, scope: :admin)
        visit student_courses_path(student)
        expect(page).to_not have_content 'Manually generate certificate'
      end
    end
  end
end
