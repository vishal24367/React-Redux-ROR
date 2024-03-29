class UsersController < ApplicationController
    before_action :verify_authenticity_token, :only => [:no_method]
    before_action :validate_user, :only => [:phone_number_verify]
    before_action :validate_token, :check_user_otp_validation, :check_user_email_validation, :only => [:verify_otp, :email_verification, :verify_email, :resend_otp, :resend_email_token]

    def no_method
    end

    def phone_number_verify
        
    end

    def verify_otp
        if @user.present?
            data = params[:data]
            otpVerificationCode = data[:verificationCode]
            if otpVerificationCode.to_i == 1111
                @user.update!(wrongOTPCount: 0)
                
                render json: { isVerification: true, errors: [], isSuccessfulSignIn: @user.successfulSignIn }, status: :ok
            else
                @user.update!(wrongOTPCount: @user.wrongOTPCount + 1)
                render json: { isVerification: false, errors: ["Invalid OTP. After 3 unsuccessful attempts, your account will be blocked for 24 hours. Only #{3-@user.wrongOTPCount} are left."] }, status: 400
            end
        else
            render json: { isVerification: false, errors: ["No User Found"] }, status: 400
        end
    end

    def email_verification
        email_verified
    end

    def verify_email
        if @user.present?
            if params[:verificationToken].to_i == 112233
                @user.update!(wrongEmailVerificationCount: 0)
                render json:{ isEmailVerifySuccessfull: true, message: "Email Verification successfull." }, status: 200
            else
                @user.update!(wrongEmailVerificationCount: @user.wrongEmailVerificationCount + 1)
                render json:{ isEmailVerifySuccessfull: false, message: "Invalid OTP. After 3 unsuccessful attempts, your account will be deleted & have to create it again. Only #{3-@user.wrongEmailVerificationCount} are left." }, status: 401
            end
        else
            render json:{ isEmailVerifySuccessfull: false, message: "", errors: ["No User Found"] }, status: 401
        end
    end

    def create
        referralCode = Referral.find_by(code: params[:referredCodeKey]) rescue false
        if referralCode.present? || params[:referredCodeKey].empty?
            create_user = User.new(firstName: params[:firstName], lastName: params[:lastName], phoneNumber: params[:phoneNumber], email: params[:email], referredCodeKey: params[:referredCodeKey], agreeToPrivacyPolicy: params[:agreeToPrivacyPolicy], token: SecureRandom.alphanumeric, source: params[:source] )
            if create_user.save
                Referral.create!(user_id: create_user.id, code: SecureRandom.alphanumeric(7))
                referralCode.update!(count: referralCode.count + 1 ) if referralCode.present?
                render json: {isUserCreated: true, errors: []}, status: :ok
            else
                render json: {isUserCreated: false, errors: create_user.errors.full_messages}, status: 400
            end
        else
            render json: {isUserCreated: false, errors: ["Invalid Referral Code applied."]}, status: 400
        end

    end

    def resend_otp
        if @user.present?
            @user.update!(wrongOTPCount: @user.wrongOTPCount + 1)
            render json: { isVerification: true, errors: [] }, status: 200
        else
            render json: { isVerification: false, errors: ["No User Found"] }, status: 401
        end
    end

    def resend_email_token
        if @user.present?
            @user.update!(wrongEmailVerificationCount: @user.wrongEmailVerificationCount + 1 )
            render json: { isEmailVerification: true, message: "An Email Verification OTP has been sent at your mail id.", errors: [] }, status: 401
        else
            render json: { isEmailVerification: false, message: "", errors: ["No User Found"] }, status: 401
        end
    end

    private
        def validate_user
            @login_user = User.find_by(phoneNumber: params[:phoneNumber])
            if @login_user.present? && @login_user.wrongOTPCount < 2 
                render json:{ isLogin: true, token: @login_user.token, errors: [] }, status: :ok
            elsif @login_user.present? && @login_user.wrongOTPCount > 2
                render json: {accountBlock: true, errors: ["Your account is currently blocked due to wrong OTP attempts."]}, status: 400
            else
                render json:{ isLogin: false, token: nil, errors: ["User not registered || Invalid Phone Number."] }, status: 400
            end
        end

        def validate_token
            data = params[:data]
            token = data[:token]
            phoneNumber = data[:phoneNumber].to_s
            email = data[:email]
            @user = User.find_by(token: token) rescue false
            if !@user.present?
                render json: {isEmailVerification: false, message: "", errors: ["Invalid User"]}, status: 401
            elsif (email.present? && @user.email != email) || (phoneNumber.present? && @user.phoneNumber != phoneNumber)
                render json: {isEmailVerification: false, message: "", errors: ["Invalid Credentials."]}, status: 400
            else
                @user
            end
        end

        def check_user_otp_validation
            if @user.present? && @user.wrongOTPCount > 2 
                render json: {accountBlock: true, errors: ["Your account is currently blocked due to wrong OTP attempts."]}, status: 400
            end
        end

        def check_user_email_validation
            if @user.present? && @user.wrongEmailVerificationCount > 2 
                render json: {accountBlock: true, errors: ["Your account is deleted due to wrong Email Verification attempts."]}, status: 401
            end
        end

        def email_verified
            if @user.present?
                data = params[:data]
                if @user.email == data[:email]
                    render json:{ isEmailVerification: true, message: "An Email Verification OTP has been sent at your mail id.", errors: [] }, status: 200
                else
                    render json:{ isEmailVerification: false, message: "", errors:["Invalid Email Credentials."] }, status: 400
                end
            else
                render json:{ isEmailVerification: false, message: "", errors: ["No User Found"] }, status: 400
            end
        end
end
