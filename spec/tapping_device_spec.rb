require "spec_helper"

RSpec.describe TappingDevice::Device do
  describe "#tap_init!" do
    let(:device) { TappingDevice::Device.new }

    after do
      device.stop!
    end

    it "tracks Student's initialization" do
      device.tap_init!(Student)

      Student.new("Stan", 18)
      Student.new("Jane", 23)

      expect(device.calls.count).to eq(2)
    end
    it "can track subclass's initialization as well" do
      device.tap_init!(HighSchoolStudent)

      HighSchoolStudent.new("Stan", 18)

      expect(device.calls.count).to eq(1)
    end
    it "doesn't track School's initialization" do
      device.tap_init!(Student)

      School.new("A school")

      expect(device.calls.count).to eq(0)
    end
    it "doesn't track non-initialization method calls" do
      device.tap_init!(Student)

      Student.foo

      expect(device.calls.count).to eq(0)
    end
  end

  describe "#tap_on!" do
    let(:device) do
      TappingDevice::Device.new do |payload|
        [payload[:receiver].object_id, payload[:method_name], payload[:return_value]]
      end
    end

    after do
      device.stop!
    end

    it "tracks method calls on the tapped object" do
      stan = Student.new("Stan", 18)
      jane = Student.new("Jane", 23)

      device.tap_on!(stan)

      stan.name
      stan.age
      jane.name
      jane.age

      expect(device.calls).to match_array(
        [
          [stan.object_id, :name, "Stan"],
          [stan.object_id, :age, 18]
        ]
      )
    end
    it "supports multiple tappings" do
      stan = Student.new("Stan", 18)

      count_1 = 0
      count_2 = 0

      device_1 = described_class.new { count_1 += 1 }
      device_2 = described_class.new { count_2 -= 1 }

      device_1.tap_on!(stan)
      device_2.tap_on!(stan)

      stan.name

      expect(count_1).to eq(1)
      expect(count_2).to eq(-1)

      device_1.stop!
      device_2.stop!
    end
    it "tracks alias" do
      c = Class.new(Student)
      c.class_eval do
        alias :alias_name :name
      end
      stan = c.new("Stan", 18)

      names = []

      device.set_block do |payload|
        names << payload[:method_name]
      end

      device.tap_on!(stan)

      stan.alias_name

      expect(names).to match_array([:alias_name])
    end

    describe "yield parameters" do
      it "detects correct arguments" do
        stan = Student.new("Stan", 18)

        arguments = []

        device.set_block do |payload|
          arguments = payload[:arguments]
        end

        device.tap_on!(stan)

        stan.age = (25)

        expect(arguments).to eq([[:age, 25]])
      end
      it "returns correct filepath and line number" do
        stan = Student.new("Stan", 18)

        filepath = ""
        line_number = 0

        device.set_block do |payload|
          filepath = payload[:filepath]
          line_number = payload[:line_number]
        end

        device.tap_on!(stan)

        line_mark = __LINE__
        stan.age

        expect(filepath).to eq(__FILE__)
        expect(line_number).to eq((line_mark+1).to_s)
      end
    end

    describe "options - exclude_by_paths: [/path/]" do
      it "skips calls that matches the pattern" do
        stan = Student.new("Stan", 18)
        count = 0

        device = described_class.new(exclude_by_paths: [/spec/]) { count += 1 }
        device.tap_on!(stan)

        stan.name

        expect(count).to eq(0)
        device.stop!
      end
    end
    describe "options - filter_by_paths: [/path/]" do
      it "skips calls that matches the pattern" do
        stan = Student.new("Stan", 18)
        count = 0

        device_1 = described_class.new(filter_by_paths: [/lib/]) { count += 1 }
        device_1.tap_on!(stan)

        stan.name
        expect(count).to eq(0)

        device_2 = described_class.new(filter_by_paths: [/spec/]) { count += 1 }
        device_2.tap_on!(stan)

        stan.name
        expect(count).to eq(1)

        device_1.stop!
        device_2.stop!
      end
    end
  end

  describe "#stop!" do
    it "stopps tapping" do
      count = 0
      device = described_class.new do |options|
        count += 1
      end
      device.tap_init!(Student)


      Student.new("Stan", 18)

      device.stop!

      Student.new("Jane", 23)

      expect(count).to eq(1)
    end
  end
end
