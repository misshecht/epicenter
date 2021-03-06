feature "Portland student does attendance sign in" do
  let(:student) { FactoryBot.create(:portland_student_with_all_documents_signed, password: 'password1', password_confirmation: 'password1') }
  let(:pair) { FactoryBot.create(:portland_student_with_all_documents_signed, password: 'password2', password_confirmation: 'password2') }

  def attendance_sign_in_solo
    visit sign_in_path
    fill_in 'email1', with: student.email
    fill_in 'password1', with: student.password
    click_button 'Attendance sign in'
  end

  def attendance_sign_in_pair
    visit sign_in_path
    fill_in 'email1', with: student.email
    fill_in 'password1', with: student.password
    fill_in 'email2', with: pair.email
    fill_in 'password2', with: pair.password
    click_button 'Attendance sign in'
  end

  context "not at school" do
    it "does not show attendance sign in page" do
      allow(IpLocation).to receive(:is_local?).and_return(false)
      visit sign_in_path
      expect(page).to have_content "Attendance sign in unavailable."
    end
  end

  context "at school" do
    before { allow(IpLocation).to receive(:is_local?).and_return(true) }

    it "shows attendance sign in page" do
      visit sign_in_path
      expect(page).to have_content "first student"
    end

    context "when soloing" do
      context "incorrect login credentials" do
        it "gives an error for an incorrect email" do
          travel_to student.course.start_date do
            visit sign_in_path
            fill_in 'email1', with: 'wrong'
            fill_in 'password1', with: student.password
            click_button 'Attendance sign in'
            expect(page).to have_content 'Invalid login credentials.'
          end
        end

        it "gives an error for an incorrect password" do
          travel_to student.course.start_date do
            visit sign_in_path
            fill_in 'email1', with: student.email
            fill_in 'password1', with: 'wrong'
            click_button 'Attendance sign in'
            expect(page).to have_content 'Invalid login credentials.'
          end
        end
      end

      it "redirects if sign in attempt on a Friday" do
        travel_to Time.zone.now.to_date.beginning_of_week + 4.days do
          attendance_sign_in_solo
          expect(current_path).to eq sign_in_path
          expect(page).to have_content 'Attendance sign in not required on Fridays.'
        end
      end

      it "redirects if not a class day" do
        travel_to student.course.start_date - 1.day do
          attendance_sign_in_solo
          expect(current_path).to eq sign_in_path
          expect(page).to have_content 'This does not appear to be a class day for you.'
        end
      end

      it "takes them to the welcome page" do
        travel_to student.course.start_date do
          attendance_sign_in_solo
          expect(current_path).to eq welcome_path
          expect(page).to have_content 'Your sign in time has been recorded'
        end
      end

      it "creates an attendance record for them" do
        travel_to student.course.start_date do
          expect { attendance_sign_in_solo }.to change { student.attendance_records.count }.by 1
        end
      end

      it 'does not update the attendance record on subsequent solo sign ins during the day' do
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 8.hours do
          attendance_sign_in_solo
        end
        attendance_record = AttendanceRecord.find_by(student: student)
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 12.hours do
          attendance_sign_in_solo
          expect(attendance_record.tardy).to be false
          expect(AttendanceRecord.count).to equal 1
        end
      end
    end

    context "when pairing" do
      context "incorrect login credentials" do
        it "gives an error for an incorrect email1" do
          visit sign_in_path
          fill_in 'email1', with: 'wrong'
          fill_in 'password1', with: student.password
          fill_in 'email2', with: pair.email
          fill_in 'password2', with: pair.password
          click_button 'Attendance sign in'
          expect(page).to have_content 'Invalid login credentials.'
        end

        it "gives an error for an incorrect email2" do
          visit sign_in_path
          fill_in 'email1', with: student.email
          fill_in 'password1', with: student.password
          fill_in 'email2', with: 'wrong'
          fill_in 'password2', with: pair.password
          click_button 'Attendance sign in'
          expect(page).to have_content 'Invalid login credentials.'
        end

        it "gives an error for an incorrect password1" do
          visit sign_in_path
          fill_in 'email1', with: student.email
          fill_in 'password1', with: 'wrong'
          fill_in 'email2', with: pair.email
          fill_in 'password2', with: pair.password
          click_button 'Attendance sign in'
          expect(page).to have_content 'Invalid login credentials.'
        end

        it "gives an error for an incorrect password1" do
          visit sign_in_path
          fill_in 'email1', with: student.email
          fill_in 'password1', with: student.password
          fill_in 'email2', with: pair.email
          fill_in 'password2', with: 'wrong'
          click_button 'Attendance sign in'
          expect(page).to have_content 'Invalid login credentials.'
        end
      end

      it "redirects if sign in attempt on a Friday" do
        travel_to Time.zone.now.to_date.beginning_of_week + 4.days do
          attendance_sign_in_pair
          expect(current_path).to eq sign_in_path
          expect(page).to have_content 'Attendance sign in not required on Fridays.'
        end
      end

      it "redirects if not a class day for student 1" do
        travel_to student.course.start_date - 1.day do
          attendance_sign_in_solo
          expect(current_path).to eq sign_in_path
          expect(page).to have_content 'This does not appear to be a class day for you.'
        end
      end

      it "redirects if not a class day for student 2" do
        travel_to pair.course.start_date - 1.day do
          attendance_sign_in_solo
          expect(current_path).to eq sign_in_path
          expect(page).to have_content 'This does not appear to be a class day for you.'
        end
      end

      it "takes them to the welcome page" do
        travel_to student.course.start_date do
          attendance_sign_in_pair
          expect(current_path).to eq welcome_path
          expect(page).to have_content 'Your attendance records have been created.'
        end
      end

      it "creates attendance records for both students" do
        travel_to student.course.start_date do
          attendance_sign_in_pair
          expect(AttendanceRecord.count).to equal 2
        end
      end

      it 'creates attendance records if one student has already signed in for the day' do
        travel_to student.course.start_date do
          FactoryBot.create(:attendance_record, student: student)
          expect { attendance_sign_in_pair }.to change { AttendanceRecord.count }.by 1
        end
      end

      it 'updates the pair id if one student has already signed in for the day' do
        travel_to student.course.start_date do
          FactoryBot.create(:attendance_record, student: student)
          expect { attendance_sign_in_pair }.to change { AttendanceRecord.first.pair_id }.from(nil).to(pair.id)
        end
      end

      it 'does not update the attendance record when signing as pairs, then solo during same day' do
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 8.hours do
          attendance_sign_in_pair
        end
        attendance_record = AttendanceRecord.find_by(student: pair)
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 12.hours do
          sign_in_as(pair)
          expect(attendance_record.tardy).to be false
        end
      end

      it 'does not update the attendance record when signing as solo, then pair during same day' do
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 8.hours do
          attendance_sign_in_solo
        end
        attendance_record = AttendanceRecord.find_by(student: student)
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 12.hours do
          attendance_sign_in_pair
          expect(attendance_record.tardy).to be false
        end
      end

      it 'does not update the attendance record when signing in solo, then as pairs, then solo again during same day' do
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 8.hours do
          attendance_sign_in_solo
        end
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 10.hours do
          attendance_sign_in_pair
        end
        attendance_record = AttendanceRecord.find_by(student: student)
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 14.hours do
          attendance_sign_in_solo
          expect(attendance_record.tardy).to be false
        end
      end
    end
  end
end

feature "Philadelphia student does attendance sign in" do
  let(:student) { FactoryBot.create(:user_with_all_documents_signed, password: 'password1', password_confirmation: 'password1') }
  let(:pair) { FactoryBot.create(:user_with_all_documents_signed, password: 'password2', password_confirmation: 'password2') }

  def attendance_sign_in_solo
    visit sign_in_path
    fill_in 'email1', with: student.email
    fill_in 'password1', with: student.password
    click_button 'Attendance sign in'
  end

  def attendance_sign_in_pair
    visit sign_in_path
    fill_in 'email1', with: student.email
    fill_in 'password1', with: student.password
    fill_in 'email2', with: pair.email
    fill_in 'password2', with: pair.password
    click_button 'Attendance sign in'
  end

  context "not at school" do
    it "does not show attendance sign in page" do
      allow(IpLocation).to receive(:is_local?).and_return(false)
      visit sign_in_path
      expect(page).to have_content "Attendance sign in unavailable."
    end
  end

  context "at school" do
    before { allow(IpLocation).to receive(:is_local?).and_return(true) }

    it "shows attendance sign in page" do
      visit sign_in_path
      expect(page).to have_content "first student"
    end

    context "when soloing" do
      context "incorrect login credentials" do
        it "gives an error for an incorrect email" do
          travel_to student.course.start_date do
            visit sign_in_path
            fill_in 'email1', with: 'wrong'
            fill_in 'password1', with: student.password
            click_button 'Attendance sign in'
            expect(page).to have_content 'Invalid login credentials.'
          end
        end

        it "gives an error for an incorrect password" do
          travel_to student.course.start_date do
            visit sign_in_path
            fill_in 'email1', with: student.email
            fill_in 'password1', with: 'wrong'
            click_button 'Attendance sign in'
            expect(page).to have_content 'Invalid login credentials.'
          end
        end
      end

      it "redirects if sign in attempt on a Friday" do
        travel_to Time.zone.now.to_date.beginning_of_week + 4.days do
          attendance_sign_in_solo
          expect(current_path).to eq sign_in_path
          expect(page).to have_content 'Attendance sign in not required on Fridays.'
        end
      end

      it "redirects if not a class day" do
        travel_to student.course.start_date - 1.day do
          attendance_sign_in_solo
          expect(current_path).to eq sign_in_path
          expect(page).to have_content 'This does not appear to be a class day for you.'
        end
      end

      it "takes them to the welcome page" do
        travel_to student.course.start_date do
          attendance_sign_in_solo
          expect(current_path).to eq welcome_path
          expect(page).to have_content 'Your sign in time has been recorded'
        end
      end

      it "creates an attendance record for them" do
        travel_to student.course.start_date do
          expect { attendance_sign_in_solo }.to change { student.attendance_records.count }.by 1
        end
      end

      it 'does not update the attendance record on subsequent solo sign ins during the day' do
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 8.hours do
          attendance_sign_in_solo
        end
        attendance_record = AttendanceRecord.find_by(student: student)
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 12.hours do
          attendance_sign_in_solo
          expect(attendance_record.tardy).to be false
          expect(AttendanceRecord.count).to equal 1
        end
      end
    end

    context "when pairing" do
      context "incorrect login credentials" do
        it "gives an error for an incorrect email1" do
          visit sign_in_path
          fill_in 'email1', with: 'wrong'
          fill_in 'password1', with: student.password
          fill_in 'email2', with: pair.email
          fill_in 'password2', with: pair.password
          click_button 'Attendance sign in'
          expect(page).to have_content 'Invalid login credentials.'
        end

        it "gives an error for an incorrect email2" do
          visit sign_in_path
          fill_in 'email1', with: student.email
          fill_in 'password1', with: student.password
          fill_in 'email2', with: 'wrong'
          fill_in 'password2', with: pair.password
          click_button 'Attendance sign in'
          expect(page).to have_content 'Invalid login credentials.'
        end

        it "gives an error for an incorrect password1" do
          visit sign_in_path
          fill_in 'email1', with: student.email
          fill_in 'password1', with: 'wrong'
          fill_in 'email2', with: pair.email
          fill_in 'password2', with: pair.password
          click_button 'Attendance sign in'
          expect(page).to have_content 'Invalid login credentials.'
        end

        it "gives an error for an incorrect password1" do
          visit sign_in_path
          fill_in 'email1', with: student.email
          fill_in 'password1', with: student.password
          fill_in 'email2', with: pair.email
          fill_in 'password2', with: 'wrong'
          click_button 'Attendance sign in'
          expect(page).to have_content 'Invalid login credentials.'
        end
      end

      it "redirects if sign in attempt on a Friday" do
        travel_to Time.zone.now.to_date.beginning_of_week + 4.days do
          attendance_sign_in_pair
          expect(current_path).to eq sign_in_path
          expect(page).to have_content 'Attendance sign in not required on Fridays.'
        end
      end

      it "redirects if not a class day for student 1" do
        travel_to student.course.start_date - 1.day do
          attendance_sign_in_solo
          expect(current_path).to eq sign_in_path
          expect(page).to have_content 'This does not appear to be a class day for you.'
        end
      end

      it "redirects if not a class day for student 2" do
        travel_to pair.course.start_date - 1.day do
          attendance_sign_in_solo
          expect(current_path).to eq sign_in_path
          expect(page).to have_content 'This does not appear to be a class day for you.'
        end
      end

      it "takes them to the welcome page" do
        travel_to student.course.start_date do
          attendance_sign_in_pair
          expect(current_path).to eq welcome_path
          expect(page).to have_content 'Your attendance records have been created.'
        end
      end

      it "creates attendance records for both students" do
        travel_to student.course.start_date do
          attendance_sign_in_pair
          expect(AttendanceRecord.count).to equal 2
        end
      end

      it 'creates attendance records if one student has already signed in for the day' do
        travel_to student.course.start_date do
          FactoryBot.create(:attendance_record, student: student)
          expect { attendance_sign_in_pair }.to change { AttendanceRecord.count }.by 1
        end
      end

      it 'updates the pair id if one student has already signed in for the day' do
        travel_to student.course.start_date do
          FactoryBot.create(:attendance_record, student: student)
          expect { attendance_sign_in_pair }.to change { AttendanceRecord.first.pair_id }.from(nil).to(pair.id)
        end
      end

      it 'does not update the attendance record when signing as pairs, then solo during same day' do
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 8.hours do
          attendance_sign_in_pair
        end
        attendance_record = AttendanceRecord.find_by(student: pair)
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 12.hours do
          sign_in_as(pair)
          expect(attendance_record.tardy).to be false
        end
      end

      it 'does not update the attendance record when signing as solo, then pair during same day' do
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 8.hours do
          attendance_sign_in_solo
        end
        attendance_record = AttendanceRecord.find_by(student: student)
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 12.hours do
          attendance_sign_in_pair
          expect(attendance_record.tardy).to be false
        end
      end

      it 'does not update the attendance record when signing in solo, then as pairs, then solo again during same day' do
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 8.hours do
          attendance_sign_in_solo
        end
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 10.hours do
          attendance_sign_in_pair
        end
        attendance_record = AttendanceRecord.find_by(student: student)
        travel_to student.course.start_date.in_time_zone(student.course.office.time_zone) + 14.hours do
          attendance_sign_in_solo
          expect(attendance_record.tardy).to be false
        end
      end
    end
  end
end

feature 'help queue link' do
  describe "links to help queue for correct office" do
    it "links to Seattle queue if connecting from Seattle IP" do
      allow(IpLocation).to receive(:is_local_computer_seattle?).and_return(true)
      visit welcome_path
      expect(page).to have_link("Queue", href: "https://seattle-help.epicodus.com")
    end

    it "links to Portland queue unless connecting from Seattle IP" do
      allow(IpLocation).to receive(:is_local_computer_seattle?).and_return(false)
      visit welcome_path
      expect(page).to have_link("Queue", href: "https://help.epicodus.com")
    end
  end
end
