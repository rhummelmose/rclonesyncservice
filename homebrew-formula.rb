class Rclonesyncservice < Formula
  desc "RClone Synchronization Service"
  homepage "http://github.com/rhummelmose/rclonesyncservice"
  head "https://github.com/rhummelmose/rclonesyncservice.git"

  bottle :unneeded

  depends_on "rclone"

  def install
    bin.install "rclonesyncservice.sh"
    bin.install_symlink bin/"rclonesyncservice.sh" => "rclonesyncservice"
  end

  test do
    ["rclonesyncservice", "rclonesyncservice.sh"].each do |cmd|
      result = shell_output("#{bin}/#{cmd} -v")
      result.force_encoding("UTF-8") if result.respond_to?(:force_encoding)
      assert_match "0.0.1", result
    end
  end
end
