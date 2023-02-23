defmodule Logflare.PartnerTest do
  use Logflare.DataCase
  alias Logflare.Partners
  alias Logflare.Repo

  describe "new/2" do
    test "inserts a new partner" do
      {:ok, partner} = Partners.new(TestUtils.random_string())
      assert partner
      assert partner.token
      assert partner.auth_token
    end
  end

  describe "list/0" do
    test "lists all partners" do
      partner = insert(:partner)
      assert [partner] == Partners.list()
    end
  end

  describe "list_users/1" do
    test "lists all users created by a partner" do
      partner = insert(:partner)

      {:ok, %{user: user}} =
        Partners.create_user(partner, %{"email" => TestUtils.random_string()})

      _other_users = insert_list(3, :user)

      assert [user_result] = Partners.list_users(partner)
      assert user_result.id == user.id
    end
  end

  describe "create_user/2" do
    test "creates new user and associates with given partner" do
      partner = insert(:partner)
      email = TestUtils.gen_email()

      assert {:ok, %{user: user, user_token: user_token}} =
               Partners.create_user(partner, %{"email" => email})

      partner = Repo.preload(partner, :users)
      assert [_user] = partner.users
      assert user.email == String.downcase(email)
      assert user_token
    end
  end

  describe "get_by_token/1" do
    test "nil if not found" do
      assert is_nil(Partners.get_by_token(TestUtils.gen_uuid()))
    end

    test "partner struct if exists" do
      %{token: token} = partner = insert(:partner)
      assert partner == Partners.get_by_token(token)
    end
  end

  describe "delete_by_token/1" do
    test "deletes partner using token" do
      %{token: token} = insert(:partner)
      assert {:ok, _} = Partners.delete_by_token(token)
    end
  end

  describe "get_user_by_token_for_partner" do
    test "fetches user if user was created by given partner" do
      partner = insert(:partner)
      email = TestUtils.gen_email()
      {:ok, %{user: %{token: token}}} = Partners.create_user(partner, %{"email" => email})

      result = Partners.get_user_by_token_for_partner(partner, token)
      assert token == result.token
    end

    test "nil if user was not created by given partner" do
      partner = insert(:partner)
      email = TestUtils.gen_email()

      {:ok, %{user: %{token: token}}} =
        Partners.create_user(insert(:partner), %{"email" => email})

      assert is_nil(Partners.get_user_by_token_for_partner(partner, token))
    end
  end
end
