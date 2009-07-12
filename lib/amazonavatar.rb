require 'rubygems'
gem 'right_aws'
gem 'mini_magick'
require 'right_aws'
require 'mini_magick'

# Instructions: include in your model with include S3Avatar
#  then you can use it like @user.put_avatar(avatar)

module AmazonAvatar
  
  def self.dir
    @@dir ||= Pathname(__FILE__).dirname.expand_path + 'amazonavatar'
  end
  
  # AmazonAvatar.access_key_id = "typeyouraccesskeyid"
  def self.access_key_id=(key)
    @@access_key_id ||= key
  end
  
  def self.access_key_id
    @@access_key_id
  end
  
  # AmaazonAvatar.secret_access_key = "typeyoursecretaccesskey"
  def self.secret_access_key=(secret)
    @@secret_access_key ||= secret
  end
  
  def self.secret_access_key
    @@secret_access_key
  end
  
  # Defin connection using RightAws
  def self.connection
    @@connection ||= RightAws::S3.new(access_key_id, secret_access_key)
  end
  
  # AmazonAvatar.bucket = "bucket_name"
  def self.bucket_name=(bucket)
    @@bucket_name ||= bucket
  end
  
  def self.bucket_name
    @@bucket_name
  end
  

  module Helpers
    def avatar_path(id, style = :original)
      "http://s3.amazonaws.com/#{AmazonAvatar.bucket_name}/avatars/#{id}/#{style.to_s}.png"
    end
  end
  
  # Adds model methods
  #  usage: 
  #  class User
  #    include AmazonAvatar::Uploader
  #  end
  #  now you can use @user.put_avatar(avatar)
  module Uploader
    module InstanceMethods
      
      # class variables
      @@avatars ||=  { 
        :original => {:filename => "original.png", :content_type => "image/png"},
        :thumb => {:filename => "thumb.png", :dimensions => "48x48", :content_type => "image/png"},
        :mini => {:filename => "mini.png", :dimensions => "24x24", :content_type => "image/png"} 
      }
      
      # Connect to bucket
      def bucket
        @bucket ||= AmazonAvatar.connection.bucket(AmazonAvatar.bucket_name, true, 'public-read')
      end
  
      # upload to s3
      def put_avatar(avatar)        
        # Original
        key1 = bucket.key("avatars/#{id}/#{@@avatars[:original][:filename]}")
        key1.put(avatar[:tempfile].read, 'public-read')
        
        # data
        data = MiniMagick::Image.from_file(avatar[:tempfile].path)
        # thumb
        key2 = bucket.key("avatars/#{id}/#{@@avatars[:thumb][:filename]}")
        key2.put(resize_and_crop(data, @@avatars[:thumb][:dimensions]).to_blob, 'public-read')
        # mini
        key3 = bucket.key("avatars/#{id}/#{@@avatars[:mini][:filename]}")
        key3.put(resize_and_crop(data, @@avatars[:mini][:dimensions]).to_blob, 'public-read')
      end
    
      # upload default start avatars. this needs to be replaced with a default image somehow
      def generate_default_avatar        
        # Original
        key1 = bucket.key("avatars/#{id}/#{@@avatars[:original][:filename]}")
        key1.put(File.new("#{AmazonAvatar.dir}/default.png").read, 'public-read')
        
        # image
        image = MiniMagick::Image.from_file("#{AmazonAvatar.dir}/default.png")
        # thumb
        key2 = bucket.key("avatars/#{id}/#{@@avatars[:thumb][:filename]}")
        key2.put(resize_and_crop(image, @@avatars[:thumb][:dimensions]).to_blob, 'public-read')
        # mini
        key3 = bucket.key("avatars/#{id}/#{@@avatars[:mini][:filename]}")
        key3.put(resize_and_crop(image, @@avatars[:mini][:dimensions]).to_blob, 'public-read')
      end
  
  
      def resize_and_crop(image, size)
        if image[:width] < image[:height]
          remove = ((image[:height] - image[:width])/2).round
          image.shave("0x#{remove}")
        elsif image[:width] > image[:height]
          remove = ((image[:width] - image[:height])/2).round
          image.shave("#{remove}x0")
        end
        image.resize("#{size}x#{size}")
        return image
      end
    end
  
    include InstanceMethods
  end
end